//
//  PhotoAlbumViewController.swift
//  VirtualTourist2
//
//  Created by Kiyoshi Woolheater on 7/8/17.
//  Copyright © 2017 Kiyoshi Woolheater. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController, MKMapViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource  {
    
    var pin: Pin?
    var annotation: MKPointAnnotation? = nil
    var imageURLs = [Data]()
    var imageObjectArray = [Image]()
    var database: Bool?
    let stack = (UIApplication.shared.delegate as! AppDelegate).stack
    var fetchedObjects: [Image]?
    
    lazy var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> = {
        
        // Create a fetch request to specify what objects this fetchedResultsController tracks.
        let fr = NSFetchRequest<NSFetchRequestResult>(entityName: "Image")
        fr.sortDescriptors = [NSSortDescriptor(key: "imageData", ascending: true)]
        
        // Specify that we only want the photos associated with the tapped pin. (pin is the relationships)
        fr.predicate = NSPredicate(format: "pin = %@", self.pin!)
        
        // Create and return the FetchedResultsController
        return NSFetchedResultsController(fetchRequest: fr, managedObjectContext: self.stack.context, sectionNameKeyPath: nil, cacheName: nil)
        
    }()
    
    
    
    @IBOutlet weak var smallMap: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // clear everything
        imageURLs.removeAll()
        imageObjectArray.removeAll()
        SavedItems.sharedInstance().imageArray.removeAll()
        SavedItems.sharedInstance().imageURLArray.removeAll()
        
        
        // add bar button item
        let barButton = UIBarButtonItem(title: "New Collection", style: .plain, target: self, action: #selector(newCollection))
        self.navigationItem.rightBarButtonItem = barButton
        
        // Check if this pin has photos stored in Core Data.
        do {
            try fetchedResultsController.performFetch()
        } catch let error as NSError {
            print("Error while trying to perform a search: \n\(error)\n\(fetchedResultsController)")
        }
        
        //set delegates and add annotation to map
        smallMap.delegate = self
        smallMap.addAnnotation(annotation!)
        smallMap.centerCoordinate = (annotation?.coordinate)!
        collectionView.delegate = self
        collectionView.dataSource = self
        
        //Fetch the objects and/or load the data
        fetchedObjects = fetchedResultsController.fetchedObjects as! [Image]
        
        if fetchedObjects?.count == 0  {
            loadImages(pageNumber: 1)
            self.collectionView.reloadData()
        } else {
            self.collectionView.reloadData()
        }
    }
    
    func loadImages(pageNumber: Int) {
        SavedItems.sharedInstance().imageArray.removeAll()
        Client.sharedInstance().getImageFromFlickr(long: (annotation?.coordinate.longitude)!, lat: (annotation?.coordinate.latitude)!, page: pageNumber) { (success, photo, array, pages, error) in
            // Handle no photos at this location
            if success {
                if photo {
                    self.label.text = "There are no photos at this location."
                } else {
                    DispatchQueue.main.async {
                        self.collectionView.reloadData()
                    }
                }
            } else {
                print(error?.userInfo as Any)
            }
        }
    }
    
    func downloadImage(imagePath: String, completionHandler: @escaping (_ imageData: Data?, _ errorString: String?) -> Void){
        let session = URLSession.shared
        let imgURL = NSURL(string: imagePath)
        let request: NSURLRequest = NSURLRequest(url: imgURL! as URL)
        
        let task = session.dataTask(with: request as URLRequest) { data, response, downloadError in
        
            if downloadError != nil {
                completionHandler(nil, "Could not download image \(imagePath)")
            } else {
                SavedItems.sharedInstance().imageArray.append(data!)
                let image = Image(pin: self.pin!, imageData: data! as NSData, context: self.stack.context)
                self.imageObjectArray.append(image)
                
                do {
                    try self.stack.context.save()
                } catch {
                    print("error saving images in data")
                }
                completionHandler(data, nil)
            }
        }
        task.resume()

    }
    
    func newCollection() {
        
        var object: [Image]
        
        if fetchedObjects?.count == 0 {
            object = imageObjectArray
        } else {
            object = fetchedObjects!
        }
        self.stack.context.perform ({
            
            for objects in object {
                self.stack.context.delete(objects)
                do {
                    try self.stack.context.save()
                } catch {
                    print("error")
                }
            }
            self.fetchedObjects?.removeAll()
            self.imageURLs.removeAll()
            self.imageObjectArray.removeAll()
            SavedItems.sharedInstance().imageURLArray.removeAll()
            
        })
        
//        self.stack.context.perform({
//            for object in self.fetchedObjects! {
//                self.stack.context.delete(object)
//            }
//            
//            do {
//                try self.stack.context.save()
//            } catch {
//                print("Error.")
//            }
//            
//            self.fetchedObjects?.removeAll()
//            self.imageURLs.removeAll()
//            self.imageObjectArray.removeAll()
//            
//            self.collectionView.reloadData()
//        })
        
        
        loadImages(pageNumber: 3)
        collectionView.reloadData()
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        if fetchedObjects?.count == 0 {
            return SavedItems.sharedInstance().imageURLArray.count
        } else {
            return (self.fetchedObjects?.count)!
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! PhotoAlbumViewCell
        cell.backgroundColor = UIColor.gray
        cell.activityIndicator.hidesWhenStopped = true
        cell.activityIndicator.startAnimating()
        cell.isUserInteractionEnabled = false
        
        if fetchedObjects?.count != 0 {
            let imageData = fetchedObjects?[(indexPath as NSIndexPath).row]
            DispatchQueue.main.async {
                cell.imageView.image = UIImage(data: imageData?.imageData as! Data)
                cell.activityIndicator.stopAnimating()
                cell.isUserInteractionEnabled = true
            }
            database = true
        } else {
            cell.imageView.image = UIImage(named: "PlaceHolder")
            
            let imagePath = SavedItems.sharedInstance().imageURLArray[indexPath.row]
            downloadImage(imagePath: imagePath) { data, error in
                if error != nil {
                    print(error)
                } else {
                    DispatchQueue.main.async {
                        cell.imageView.image = UIImage(data: data!)
                        cell.activityIndicator.stopAnimating()
                        cell.isUserInteractionEnabled = true
                    }
                }
            }
            
            database = false
            
        }
        
        return cell
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath:IndexPath) {
        
        var object: Image?
        
        if fetchedObjects?.count == 0 {
            object = imageObjectArray[indexPath.row]
        } else {
            object = fetchedObjects?[indexPath.row]
        }
        if database! {
            fetchedObjects?.remove(at: indexPath.row)
            stack.context.delete(object!)
            do {
                try stack.context.save()
            } catch {
                print("error saving")
            }
            collectionView.reloadData()
        } else {
            SavedItems.sharedInstance().imageURLArray.remove(at: indexPath.row)
            stack.context.delete(object!)
            do {
                try stack.context.save()
            } catch {
                print("error saving")
            }
            collectionView.reloadData()
        }
    }
    
}
