//
//  Client.swift
//  VirtualTourist2
//
//  Created by Kiyoshi Woolheater on 7/8/17.
//  Copyright © 2017 Kiyoshi Woolheater. All rights reserved.
//

import Foundation
import UIKit
class Client: NSObject {
    
    let session = URLSession.shared
    let stack = (UIApplication.shared.delegate as! AppDelegate).stack
    
    func getImageFromFlickr(pin: Pin, long: Double, lat: Double, page: Int, completionHandlerForGetImage: @escaping(_ success: Bool, _ photo: Bool , _ url: [String]?,_ pages: Int ,_ error: NSError?) -> Void) -> URLSessionDataTask {
        
        let methodParameters = [
            Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.LocationPhotosMethod,
            Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
            Constants.FlickrParameterKeys.Latitude: lat,
            Constants.FlickrParameterKeys.Longitude: long,
            Constants.FlickrParameterKeys.NumPhotos: Constants.FlickrParameterValues.NumPhotos,
            Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
            Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
            Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback,
            Constants.FlickrParameterKeys.Pages: Constants.FlickrParameterValues.Pages,
            Constants.FlickrParameterKeys.Page: page
            ] as [String : Any]
        
        // create url and request
        let urlString = Constants.Flickr.APIBaseURL + escapedParameters(methodParameters as [String:AnyObject])
        
        let url = URL(string: urlString)!
        let request = URLRequest(url: url)
        
        // create network request
        let task = session.dataTask(with: request) { (data, response, error) in
            
            // if an error occurs and print it
            func displayError(_ error: String) {
                print("URL at time of error: \(url)")
                let userInfo = [NSLocalizedDescriptionKey : error]
                completionHandlerForGetImage(false, false, nil, 0, NSError(domain: "taskError", code: 1, userInfo: userInfo))
            }
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                displayError("There was an error with your request: \(String(describing: error))")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                displayError("Your request returned a status code other than 2xx!")
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                displayError("No data was returned by the request!")
                return
            }
            
            // parse the data
            let parsedResult: [String:AnyObject]!
            
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                displayError("Could not parse the data as JSON: '\(data)'")
                return
            }
            
            /* GUARD: Did Flickr return an error (stat != ok)? */
            guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String, stat == Constants.FlickrResponseValues.OKStatus else {
                displayError("Flickr API returned an error. See error code and message in \(parsedResult)")
                return
            }
            
            /* GUARD: Are the "photos" and "photo" keys in our result? */
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject], var numberOfPages = photosDictionary[Constants.FlickrParameterKeys.Pages] as? Int, let photoArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as? [[String:AnyObject]] else {
                displayError("Cannot find keys '\(Constants.FlickrResponseKeys.Photos)' and '\(Constants.FlickrResponseKeys.Photo)' in \(parsedResult)")
                return
            }
            
            print(numberOfPages)
            
            numberOfPages = min(numberOfPages,4000/18)
            
            print(numberOfPages)
            
            if numberOfPages == 0 {
                completionHandlerForGetImage(true, true, nil, numberOfPages, nil)
            }
            
            var imageArray = [String]()
            
            /* GUARD: Does our photo have a key for 'url_m'? */
            for key in photoArray {
                guard let imageUrlString = key[Constants.FlickrResponseKeys.MediumURL] as? String else {
                    displayError("Cannot find key '\(Constants.FlickrResponseKeys.MediumURL)' in \(key)")
                    return
                }
                
                imageArray.append(imageUrlString)
            }
            
            for value in imageArray {
                SavedItems.sharedInstance().imageURLArray.append(value)
            }
            
            //main queue 
            //create image entite without data
            completionHandlerForGetImage(true, false, imageArray, numberOfPages, nil)
        }
        
        // start the task!
        task.resume()
        return task
        
        
    }
    
    private func escapedParameters(_ parameters: [String:AnyObject]) -> String {
        
        if parameters.isEmpty {
            return ""
        } else {
            var keyValuePairs = [String]()
            
            for (key, value) in parameters {
                // make sure that it is a string value
                let stringValue = "\(value)"
                
                // escape it
                let escapedValue = stringValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                
                // append it
                keyValuePairs.append(key + "=" + "\(escapedValue!)")
            }
            return "?\(keyValuePairs.joined(separator: "&"))"
        }
    }
    
    class func sharedInstance() -> Client {
        
        struct Singleton {
            
            static var sharedInstance = Client()
        }
        return Singleton.sharedInstance
    }
}
