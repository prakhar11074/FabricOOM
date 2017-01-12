# FabricOOM
Sample iOS application to record OOM events in Fabric allowing custom analytics. Built using https://github.com/Split82/iOSMemoryBudgetTest as base.

#Why is it Needed
iOS doesn't report Out of memory sessions as exceptions, but they are still equivalent to a crash to the end user. Thus it is important to eliminate those. Fabric reports(I feel they report more than the actual OOM count) OOM sessions but doesn't provide any detail. 

#Details
- The logic is inspired from :
https://docs.fabric.io/apple/crashlytics/OOMs.html and https://code.facebook.com/posts/1146930688654547/reducing-fooms-in-the-facebook-ios-app/. 
- [Analytics recordOutOfMemoryWarning] records each memory warning
- [Analytics sendOutOfMemoryEvent] records the actual Out Of Memory Event

#How to use
- Change the Fabric credentials to your project. 
- Add the required methods to your app delegate
- Change customData dictionary in [Analytics recordOutOfMemoryWarning] , [Analytics sendOutOfMemoryEvent] as per your need.