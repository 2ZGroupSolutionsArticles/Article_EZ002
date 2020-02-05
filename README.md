![header](https://github.com/SezorusArticles/Article_EZ002/blob/master/Images/header1.jpg)
<br><br>

# Understanding AVAssetResourceLoaderDelegate

Most people want to save time, money, and other resources in regards to all aspects of life. However, in this article, we will talk about software development for the iOS platform. So all these moments are right for Users of the mobile Applications too. An app should look nice, does something useful, and provide feedback as fast as possible. But usually, a lot of in App contents are somewhere in a Cloud. So we need to load them first, at least some part... maybe just a few bits at the beginning. There're many types of services which provide access to online video, different podcasts, and music. Or maybe chatting App with an ability to send short video messages. All should work fast or at least looks like so.

Let's look about playing audio/video files from remote storage. A user can play the same track ten times a day. And he can fell in sleep while looking on loading activity if it appears every time. Or not, usually he deletes the App from the device. But we want to have the best App in the world. So let's make our users happy! And avoid loading state as possible. Load data just once and cache it locally. You always have a chance to delete outdated and not actual data later. Let's begin with a simple case and research on how we can deal with such tasks. For example, we have a short video record which can be viewed many times. In any case, we'll need to download it. At least once explicitly. Alternatively, it will do for you the 'black box' under the hood. We will use the *AVPlayer* to play this video file in this example.

#

The fastest and easiest way to save the video file to the disk is to use *AVAssetExportSession*. You can create it with the *AVURLAsset* and quality preset. Then assign the *outputURL* and *outputFileType*. After call *exportAsynchronously* method to know when the exporter finished the task. That's all. It can be a good solution when you have just a few seconds in a record. With this approach, we can achieve the goal and save some development time.

``` swift
func exportSession(forAsset asset: AVURLAsset) {
        if !asset.isExportable { return }
        
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            print("Failed to create export session")
            return
        }
        
        let fileName = asset.url.lastPathComponent
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
        let outputURL = documentsDirectory.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            do {
                try FileManager.default.removeItem(at: outputURL)
            } catch let error {
                print("Failed to delete file with error: \(error)")
            }
        }
        
        exporter.outputURL = outputURL
        exporter.outputFileType = AVFileType.mp4
        
        exporter.exportAsynchronously {
            print("Exporter did finish")
            if let error = exporter.error {
                print("Error \(error)")
            }
        }
    }
```

However, what if we need a similar feature for a movie or podcast? A user can pause it and continue watching on the next day. It can be not enough time to download the whole file with *AVAssetExportSession*. So here we have *AVAssetResourceLoaderDelegate*. It can help us to implement similar logic as provides exporter and even more. 

Let's dive in it to understand how does it work, and how we can use it.
Now we will talk about basics and a simple clone of the exporter. This example is not the optimal way. In the next article, we implement more interesting logic with *AVAssetResourceLoaderDelegate*.

## Intercepting original AVAssetResourceLoadingRequests

At the beginning we have:
- Some *videoURL* to the remote file. 
- *AVPlayer* to play content in the App. We use it with the wrapper *MediaPlayer* to make the life a bit easier.
- And *SimpleResourceLoaderDelegate* which we need to implement. It will do all the magic for us.

View controller has a separate method to create and setup *MediaPlayer*.
```swift
func createPlayer() -> MediaPlayer {
        guard let url = URL(string: "https://www.quirksmode.org/html5/videos/big_buck_bunny.mp4") else {
            fatalError("Wrong video url.")
        }
        
        self.loaderDelegate = SimpleResourceLoaderDelegate(withURL: url)
        let videoAsset = AVURLAsset(url: self.loaderDelegate!.streamingAssetURL)
        videoAsset.resourceLoader.setDelegate(self.loaderDelegate, queue: DispatchQueue.main)
        self.loaderDelegate?.completion = { localFileURL in
            if let localFileURL = localFileURL {
                print("Media file saved to: \(localFileURL)")
            } else {
                print("Failed to download media file.")
            }
        }
        
        let player = MediaPlayer(withAsset: videoAsset)
        player.delegate = self
        player.playerView = self.playerView
        
        return player
    }
```

First, we create a custom loader delegate. <br>
Then we can create *AVURLAsset* with our videoURL. **Attention, we should not pass the original URL like `https://www.some.com/short.mp4`, but a bit modified `https-demoloader://www.some.com/short.mp4` if we want to our SimpleResourceLoaderDelegate be invoked.**<br>
After we can assign *loaderDelegate* to *videoAsset*.<br>
And finally, create *AVPlayer* (in our case wrapper *MediaPlayer*) with the *videoAsset*.

Let's go to the *AVAssetResourceLoaderDelegate* implementation and look what's going on in it.
Right now we are interested in just two methods:

- First one invokes when some data should be loaded
```swift
func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool
```

- Second invokes when some previous request was canceled
```swift
func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest)
```

<br>When the App starts playing the video first method invokes when the player asks about a new batch of data. With our delegate, we intercept requests and load all data with our self and provide back to the origin *AVAssetResourceLoadingRequest* data which we have. All provided data is our responsibility from now.
<br>
Here's a diagram of *AVAssetResourceLoadingRequests*:
<br><br>

![Img1](https://github.com/SezorusArticles/Article_EZ002/blob/master/Images/Img1.jpg)
<br>
As we can see *AVAssetResourceLoader* sends few requests to get the info about the file. And junks of data with *requestedOffset* and *requestedLength*. 

We need to save all valid *AVAssetResourceLoadingRequest* somewhere. Let's use for simple Array for that
```swift
private var loadingRequests = [AVAssetResourceLoadingRequest]()
```
Also we need to handle request cancelation. In this case we will just remove saved origin request from the array.
```swift
if let index = self.loadingRequests.firstIndex(of: loadingRequest) {
    self.loadingRequests.remove(at: index)
}
```

## Downloading real data
Now we need to download all the required data for the video. We can create *URLSession* with the single *URLSessionDataTask* to keep everything simple in this example. Also, we need to implement a few methods from *URLSessionTaskDelegate* and *URLSessionDataDelegate*.<br>
We need these methods:
- To process the response with file info and fill with it info request from origin *AVAssetResourceLoadingRequest*
```swift
func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
```
- To process data from our video file. We will store all the data in memory for now. It's not the best solution, but it is enough for short video from our example.
```swift
func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data)
```
- To process error from task loading or successful completion of the loading.
```swift
func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
```

<br><br>Now we can create our *URLSession* with code
```swift
func createURLSession() -> URLSession {
        let config = URLSessionConfiguration.default
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        return URLSession(configuration: config, delegate: self, delegateQueue: operationQueue)
    }
```
All received data we will save in the variable 
```swift
private lazy var mediaData = Data()
```
And then we need to create our data task when we will receive the first *AVAssetResourceLoadingRequest*
```swift
if self.urlSession == nil {
        self.urlSession = self.createURLSession()
        let task = self.urlSession!.dataTask(with: self.url)
        task.resume()
    }
```

#

So we have intercepted all origin requests from the resource loader and have created our data task to download video data. So now we can send chunks of downloaded data to the saved *AVAssetResourceLoadingDataRequest*.
But don't forget about *AVAssetResourceLoadingContentInformationRequest* too. When we received the *URLResponse* from the *URLSessionDataTask* we should fill with it the *AVAssetResourceLoadingContentInformationRequest*.<br>
It looks like
```swift
func fillInfoRequest(request: inout AVAssetResourceLoadingRequest, response: URLResponse) {
        request.contentInformationRequest?.isByteRangeAccessSupported = true
        request.contentInformationRequest?.contentType = response.mimeType
        request.contentInformationRequest?.contentLength = response.expectedContentLength
    }
```
And every time when we receive new data from data task we can check our saved origin *loadingRequests* and fill them with available data. And maybe finish some of them.
<br><br>
For example, we have this case. Some data already downloaded. *AVAssetResourceLoadingDataRequest* has some *requestedOffset* and *requestedLength*. Also, we already sent some data to it, so *currentOffset* is not 0 too.
Looks like on the diagram
<br>

![Img2](https://github.com/SezorusArticles/Article_EZ002/blob/master/Images/Img2.jpg)
<br>
Now we need to calculate which pease of data available for the origin request.<br>
Logic looks like
<br>

![Img3](https://github.com/SezorusArticles/Article_EZ002/blob/master/Images/Img3.jpg)
<br>
Required steps:
- Check with the length of downloaded data we can pass to the request
- Respond with a chunk of data
- Check if we sent all required data to the request, and finish it if so
<br>
In code<br>

```swift
func checkAndRespond(forRequest dataRequest: AVAssetResourceLoadingDataRequest) -> Bool {
        let downloadedData          = self.mediaData
        let downloadedDataLength    = Int64(downloadedData.count)
        
        let requestRequestedOffset  = dataRequest.requestedOffset
        let requestRequestedLength  = Int64(dataRequest.requestedLength)
        let requestCurrentOffset    = dataRequest.currentOffset
        
        if downloadedDataLength < requestCurrentOffset {
            return false
        }
        
        let downloadedUnreadDataLength  = downloadedDataLength - requestCurrentOffset
        let requestUnreadDataLength     = requestRequestedOffset + requestRequestedLength - requestCurrentOffset
        let respondDataLength           = min(requestUnreadDataLength, downloadedUnreadDataLength)

        dataRequest.respond(with: downloadedData.subdata(in: Range(NSMakeRange(Int(requestCurrentOffset), Int(respondDataLength)))!))
        
        let requestEndOffset = requestRequestedOffset + requestRequestedLength
        
        return requestCurrentOffset >= requestEndOffset
    }
```

## Finishing loading

When we finish with downloading the data, we can save it to a local file for example.

```swift
func saveMediaDataToLocalFile() -> URL? {
        guard let docFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileName = self.url.lastPathComponent
        let fileURL = docFolderURL.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch let error {
                print("Failed to delete file with error: \(error)")
            }
        }
        
        do {
            try self.mediaData.write(to: fileURL)
        } catch let error {
            print("Failed to save data with error: \(error)")
            return nil
        }
        
        return fileURL
    }
```

## We are done!

That's all with the basics of the *AVAssetResourceLoaderDelegate*. We understand how does it work and how to deal with it. You can try the Demo project.<br>

### Author
Yevhenii(Eugene) Zozulia

Email: yevheniizozulia@sezorus.com

LinkedIn: [EugeneZI](https://www.linkedin.com/in/eugenezi/)
