# RTCoreDataStack

Core Data stack I use in all my modern iOS apps

I have used this library in several fairly large and complex apps with lots of background use, thus it's fairly stable and usable in practice. Still, test all assumptions like hell.

The library is fairly small and well commented.

## Main Features

By default, when library is instantiated it will create two instances of `NSPersistentStoreCoordinator`: `mainPSC` and `writerPSC`. None of them is directly accessible, they are used inside the library.

### Main MOC

```
@property (nonatomic, strong, readonly) NSManagedObjectContext *mainManagedObjectContext;
```

It will also automatically create an instance of `NSManagedObjectContext` merge policy set to favor state of objects in the persistent store (on the disk) versus those in the memory.

You should use this MOC as your UI / main thread MOC.

### Useful MOCs

Library has three additional useful methods, to create specific MOCs.

```
- (NSManagedObjectContext *)importerManagedObjectContext;
```

This method returns MOC attached to mentioned `writerPSC` and its merge policy *favors state of objects in the memory*. This makes it perfect for background imports, as whatever is created / changed it would trample objects on the disk.

Call this method from background queues and use it to process items and save them directly to disk, without ever touching main thread. Since such processing is fairly short, it's very easy to import just about anything and still keep your UI thread fluent.

```
- (NSManagedObjectContext *)temporaryManagedObjectContext;
```

This methods returns MOC created as child context of the `mainManagedObjectContext` but with rollback merge policy. This means that you can do whatever you want in that MOC, *objects in it will never get to the main MOC* nor will they ever be saved to disk.

I use this when I need a temporary copy of MOs for UI purposes. A poor man's `copy` for `NSManagedObject` instances.

```
- (NSManagedObjectContext *)creatorManagedObjectContext;
```

This method returns MOC created as child context of the `mainManagedObjectContext` but this time with merge policy that will *override whatever you have in the main MOC* and further along, all the way to the disk.

Textbook usage for this is when you need to create new objects, like new order in shopping app. Since this is created in new child MOC, you can freely do whatever in it, without influencing objects in main MOC. If you delete the creatorMOC, everything goes away, no harm done. If you save that context, everything is automatically propagated to main MOC and also further to the disk.

## Killer feature: automatic, smart merge on save

If you have read carefully, you may have noticed that `importerMOC` is connected to `writerPSC`. This means that objects created in it and later saved to the persistent store will never reach the main MOC and thus your UI will have no idea about them.

If you already have some objects loaded in mainMOC and shown in the UI and those objects are updated through the background import and saved to disk, your main MOC will have no idea about those changes. Your `NSFetchedResultsControllerDelegate` callbacks will also not pick them up.

So how to get to them?

**`RTCoreDataStack` handles this automatically for you!**

It register itself as observer for `NSManagedObjectContextDidSaveNotification` from any MOC. Then it smartly dismisses any notifications coming from anything except the MOCs attached to writerPSC.

By the power of Core Data, this merge will refresh all objects already loaded in main MOC and will ignore all the rest. This gives you the best of all worlds: you can import 1000s of objects in the background and if you are showing just 10 of them, those 10 will be updated and the rest never clog your UI thread.

Additionally, if you smartly chunk out your background import calls, you are free to continually import data – say through web sockets – and never, ever encounter a merge conflict nor experience memory issues.

## Options

```
@property (nonatomic, getter=isMainMOCReadOnly) BOOL mainMOCReadOnly;
```

This property will make your mainMOC readonly. If you attempt to save anything in it, those saves will be ignored. 

Default is `NO`.

```
@property (nonatomic, getter=shouldMergeIncomingSavedObjects) BOOL mergeIncomingSavedObjects;
```

This property allows you to turn off automatic merge between the importerMOC and mainMOC.

Default is `YES` (meaning, do the merge).

## Usage as Singleton

```
+ (RTCoreDataManager *)defaultManager;
```

This is recommended way to use the library. 
You need to setup the singleton object using one of the following methods.

```
- (void)setupWithCallback:(InitCallbackBlock)callback;
```

This will merge all Core Data models found in the app, create `.sqlite` file named the same as your app and save it in application's `NSDocumentDirectory` folder.

```
- (void)setupWithDataModelNamed:(NSString *)dataModelName callback:(InitCallbackBlock)callback;
```

This will take the supplied Core Data model, create `.sqlite` file named the same as your app and save it in application's `NSDocumentDirectory` folder.

```
- (void)setupWithDataModelNamed:(nullable NSString *)dataModelName storeURL:(NSURL *)storeURL callback:(InitCallbackBlock)callback;
```

This will take the supplied Core Data model and create the disk files at the supplied URL. This is useful when you need to place them at the shared App Group location (think extensions, iCloud).

If you don't supply the `dataModelName`, it will merge whatever model files it finds in the app's bundle.

### Non-singleton usage

However, you are free to create as many instances as you want and not use the `defaultManager`. There are 3 equivalent methods to use here:

```
- (instancetype)initWithCallback:(InitCallbackBlock)callback;
```
```
- (instancetype)initWithDataModelNamed:(NSString *)dataModelName callback:(InitCallbackBlock)callback;
```
```
- (instancetype)initWithDataModelNamed:(NSString *)dataModelName storeURL:(NSURL *)storeURL callback:(InitCallbackBlock)callback;
```

## Examples

The supplied demo project shows how the background importing works in practice. 

While the app is running, it continually downloads 100s of stock tickets from Yahoo! Finance, while showing just few of them.