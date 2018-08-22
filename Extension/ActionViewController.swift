//
//  ActionViewController.swift
//  Extension
//
//  Created by Charles Martin Reed on 8/22/18.
//  Copyright © 2018 Charles Martin Reed. All rights reserved.
//

import UIKit
import MobileCoreServices

class ActionViewController: UIViewController {
    @IBOutlet weak var script: UITextView!
    
    //these are the values being transmitted by Safari, to iOS and then forwarded to our extension
    var pageTitle = ""
    var pageURL = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        
        //handling potential issues with the virtual keyboard in our layout
        //grab a reference to the default notification center
        let notificationCenter = NotificationCenter.default
        
        //object is nil because we don't care who ends the notification
        //we're watching for when the keyboard will hide and when it will change frame and responding with our method
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: Notification.Name.UIKeyboardWillHide, object: nil)
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: Notification.Name.UIKeyboardWillChangeFrame, object: nil)
        
        
        //extensionContext allows us to control how our extension interacts with the parent app
        //inputItems is an array of data the parent app sends to the extension for it to use; if it exists, we typecast it
        //we load the first attachment we pulled from our inputItem array - this happens asynchronously, so we use a closure
        //the closure takes two params, one for the dictionary we receive from our provider and the other for the error that could occur
        if let inputItem = extensionContext?.inputItems.first as? NSExtensionItem {
            if let itemProvider = inputItem.attachments?.first as? NSItemProvider {
                itemProvider.loadItem(forTypeIdentifier: kUTTypePropertyList as String) { [unowned self] (dict, error) in
                    
                    //we use NSDictionary because it doesn't care what type is placed into it. Accordingly, it's flexible but dangerous.
                    let itemDictionary = dict as! NSDictionary
                    
                    //we typecast BACK to a NSDictionary so we can pull the values out with keys
                    let javaScriptValues = itemDictionary[NSExtensionJavaScriptPreprocessingResultsKey] as! NSDictionary
                    
                    //placing the values from the dict into our variables
                    self.pageTitle = javaScriptValues["title"] as! String
                    self.pageURL = javaScriptValues["URL"] as! String
                    
                    //updating our title via the main thread
                    //we didn't need [unowned self] in this closure because we're still within a closure. That means the strong ref cycle has already been sidestepped.
                    DispatchQueue.main.async {
                        self.title = self.pageTitle
                    }
                }
            }
        }
    }

    @objc func adjustForKeyboard(notification: Notification) {
        //a dictionary granted by Notification Center containing all the notification specific information. We'll use this to get the end frame for our keyboard's soon to be position.
        let userInfo = notification.userInfo!
        
        //Obj-C arrays and dicts can't hold CGRects, so we have to typecast as NSValue
        let keyboardScreenEndFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window)
        
        //when we hide the keyboard, set the Insets to zero, otherwise set them such that the text will not be blocked by the keyboard in portrait or landscape. In this case, we're using this as a fix for the user plugging in a hardware keyboard.
        if notification.name == Notification.Name.UIKeyboardWillHide {
            script.contentInset = UIEdgeInsets.zero
        } else {
            script.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardViewEndFrame.height, right: keyboardScreenEndFrame.width)
        }
        
        //adjust the scroll indicator to fit our adjusted textView
        script.scrollIndicatorInsets = script.contentInset
        
        let selectedRange = script.selectedRange
        script.scrollRangeToVisible(selectedRange)
    }

    @IBAction func done() {
        //We're going to modify the method so that it passes back the text the user entered in the text view
        
        //create an NSExtensionItem
        let item = NSExtensionItem()
        //create an dictionary with our key and the value being the text the user entered
        let argument: NSDictionary = ["customJavaScript": script.text]
        //make a dictionary containing our argument dictionary as the value and our FinalizeArgumentKey as the key
        let webDictionary: NSDictionary = [NSExtensionJavaScriptFinalizeArgumentKey: argument]
        //wrap the big dictionary instead of an NSItemProvider object
        let customJavaScript = NSItemProvider(item: webDictionary, typeIdentifier: kUTTypePropertyList as String)
        //add that item provider into our NSExtensionItem as an attachment
        item.attachments = [customJavaScript]
        
        //in the Action.js, we'll use eval on our passed customJavaScript 
        extensionContext!.completeRequest(returningItems: [item], completionHandler: nil)
    }

}
