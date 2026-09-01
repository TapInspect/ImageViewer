//
//  UIViewController.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 18/03/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//

import UIKit

public extension UIViewController {

    func presentImageGallery(_ gallery: GalleryViewController, completion: (() -> Void)? = {}) {

        let navigationController = UINavigationController(rootViewController: gallery)
        navigationController.modalPresentationStyle = gallery.modalPresentationStyle
        present(navigationController, animated: false, completion: completion)
    }
}
