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
        ///This less known/used presentation style option allows the contents of parent view controller presenting the gallery to "bleed through" the blurView. Otherwise we would see only black color.
        navigationController.modalPresentationStyle = .overFullScreen
        present(navigationController, animated: false, completion: completion)
    }
}
