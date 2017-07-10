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
    
    lazy var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> = {
        
        // Create a fetch request to specify what objects this fetchedResultsController tracks.
        let fr = NSFetchRequest<NSFetchRequestResult>(entityName: "Image")
        fr.sortDescriptors = [NSSortDescriptor(key: "imageData", ascending: true)]
        
        // Specify that we only want the photos associated with the tapped pin. (pin is the relationships)
        fr.predicate = NSPredicate(format: "pin = %@", self.pin!)
        
        // Create and return the FetchedResultsController
        return NSFetchedResultsController(fetchRequest: fr, managedObjectContext: self.stack.context, sectionNameKeyPath: nil, cacheName: nil)
        
    }()
    
    let stack = (UIApplication.shared.delegate as! AppDelegate).stack
    
    @IBOutlet weak var smallMap: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // clear everything
        imageURLs.removeAll()
        SavedItems.sharedInstance().imageArray.removeAll()
        SavedItems.sharedInstance().imageURLArray.removeAll()
        
        // Check if this pin has photos stored in Core Data.
        do {
            try fetchedResultsController.performFetch()
        } catch let error as NSError {
            print("Error while trying to perform a search: \n\(error)\n\(fetchedResultsController)")
        }
        
        smallMap.delegate = self
        smallMap.addAnnotation(annotation!)
        smallMap.centerCoordinate = (annotation?.coordinate)!
        collectionView.delegate = self
        collectionView.dataSource = self
        
        let fetchedObjects = fetchedResultsController.fetchedObjects as! [Image]
        for image in fetchedObjects {
            print(image.imageData)
        }
        if fetchedObjects.count == 0  {
            loadImages()
            self.collectionView.reloadData()
        } else {
            self.collectionView.reloadData()
        }
        
        
    }
    
    func loadImages() {
        SavedItems.sharedInstance().imageArray.removeAll()
        Client.sharedInstance().getImageFromFlickr(long: (annotation?.coordinate.longitude)!, lat: (annotation?.coordinate.latitude
            )!) { (success, photo, error) in
                // Handle no photos at this location
                if success {
                    if photo {
                        self.label.text = "There are no photos at this location."
                    } else {
                        self.loadImageData(SavedItems.sharedInstance().imageURLArray)
                        self.collectionView.reloadData()
                    }
                } else {
                    print(error?.userInfo as Any)
                }
        }
    }
    
    func loadImageData(_ imageURLs: [String]) {
        for url in imageURLs {
            let imageURLString = URL(string: url)
            if let imageData = try? Data(contentsOf: imageURLString!) {
                let picture = UIImage(data: imageData)
                let data = UIImageJPEGRepresentation(picture!, 1)
                let image = Image(pin: pin!, imageData: data as! NSData, context: self.stack.context)
                //let image = Images(imageData: imageData as NSData, context: stack.context)
                SavedItems.sharedInstance().imageArray.append(imageData)
                self.imageURLs.append(imageData)
                do {
                    try stack.context.save()
                } catch {
                    print("error saving images in data")
                }
            } else {
                print("Image does not exist at \(url)")
            }
        }
        
        self.collectionView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.imageURLs.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! PhotoAlbumViewCell
        
        let photosToLoad = fetchedResultsController.object(at: indexPath) as! Image
        
        if photosToLoad.imageData == nil {
            imageURLs = SavedItems.sharedInstance().imageArray
            let imageData = self.imageURLs[(indexPath as NSIndexPath).row]
            
            // Set the name and image
            DispatchQueue.main.async {
                cell.imageView.image = UIImage(data: imageData)
            }
        } else {
            DispatchQueue.main.async {
                cell.imageView.image = UIImage(data: photosToLoad.imageData as! Data)
            }
        }
        return cell
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath:IndexPath) {
        
        
    }
}
