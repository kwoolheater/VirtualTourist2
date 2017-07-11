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
    var database: Bool?
    var insertedIndexPaths: [IndexPath]!
    var deletedIndexPaths: [IndexPath]!
    var updatedIndexPaths: [IndexPath]!
    
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
    var fetchedObjects: [Image]?
    
    @IBOutlet weak var smallMap: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // clear everything
        imageURLs.removeAll()
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
        
        smallMap.delegate = self
        smallMap.addAnnotation(annotation!)
        smallMap.centerCoordinate = (annotation?.coordinate)!
        collectionView.delegate = self
        collectionView.dataSource = self
        
        fetchedObjects = fetchedResultsController.fetchedObjects as! [Image]
        
        if fetchedObjects?.count == 0  {
            loadImages()
            
            self.collectionView.reloadData()
        } else {
            self.collectionView.reloadData()
        }
    }
    
    func loadImages() {
        SavedItems.sharedInstance().imageArray.removeAll()
        Client.sharedInstance().getImageFromFlickr(long: (annotation?.coordinate.longitude)!, lat: (annotation?.coordinate.latitude)!) { (success, photo, error) in
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
                _ = Image(pin: pin!, imageData: data! as NSData, context: self.stack.context)
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
    
    func newCollection() {
        fetchedObjects?.removeAll()
        imageURLs.removeAll()
        
        collectionView.reloadData()
        
        loadImages()
        collectionView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        if fetchedObjects?.count == 0 {
            return self.imageURLs.count
        } else {
            return (self.fetchedObjects?.count)!
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! PhotoAlbumViewCell
        cell.backgroundColor = UIColor.gray
        cell.activityIndicator.hidesWhenStopped = true
        cell.activityIndicator.startAnimating()
        
        if fetchedObjects?.count != 0 {
            let imageData = fetchedObjects?[(indexPath as NSIndexPath).row]
            DispatchQueue.main.async {
                cell.imageView.image = UIImage(data: imageData?.imageData as! Data)
                cell.activityIndicator.stopAnimating()
            }
            database = true
        } else {
            imageURLs = SavedItems.sharedInstance().imageArray
            let imageData = self.imageURLs[(indexPath as NSIndexPath).row]
            
            // Set the name and image
            DispatchQueue.main.async {
                cell.imageView.image = UIImage(data: imageData)
                cell.activityIndicator.stopAnimating()
            }
            database = false
        }
        return cell
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath:IndexPath) {
        
        let object = fetchedObjects?[indexPath.row]
        
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
            imageURLs.remove(at: indexPath.row)
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

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        insertedIndexPaths = [IndexPath]()
        deletedIndexPaths = [IndexPath]()
        updatedIndexPaths = [IndexPath]()
    }
    
    // https://www.youtube.com/watch?v=0JJJ2WGpw_I (13:50-15:00)
    // This method is only called when anything in the context has been added or deleted. It collects the indexPaths that have changed. Then, in controllerDidChangeContent, the changes are applied to the UI.
    // The indexPath value is nil for insertions, and the newIndexPath value is nil for deletions.
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
            
        case .insert:
            insertedIndexPaths.append(newIndexPath!)
            print("Inserted a new index path")
            break
            
        case .delete:
            deletedIndexPaths.append(indexPath!)
            print("Deleted an index path")
            break
            
        case .update:
            updatedIndexPaths.append(indexPath!)
            print("Updated an index path")
            break
            
        default:
            break
        }
    }
    
    // https://www.youtube.com/watch?v=0JJJ2WGpw_I (18:15)
    // Updates the UI so that it syncs up with Core Data. This method doesn't change anything in Core Data.
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        collectionView.performBatchUpdates({
            
            for indexPath in self.insertedIndexPaths{
                self.collectionView.insertItems(at: [indexPath as IndexPath])
            }
            
            for indexPath in self.deletedIndexPaths{
                self.collectionView.deleteItems(at: [indexPath as IndexPath])
            }
            
            for indexPath in self.updatedIndexPaths{
                self.collectionView.reloadItems(at: [indexPath as IndexPath])
            }
            
        }, completion: nil)
        
    }
    
}
