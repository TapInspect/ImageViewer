//
//  ThumbnailsViewController.swift
//  ImageViewer
//
//  Created by Zeno Foltin on 07/07/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//

import UIKit

class ThumbnailsViewController: UICollectionViewController {

    fileprivate let reuseIdentifier = "ThumbnailCell"

    var onItemSelected: ((Int) -> Void)?
    weak var itemsDataSource: GalleryItemsDataSource!
    lazy var closeButton = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(close))

    required init(itemsDataSource: GalleryItemsDataSource) {
        self.itemsDataSource = itemsDataSource

        super.init(collectionViewLayout: ThumbnailsViewController.makeLayout())
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func makeLayout() -> UICollectionViewLayout {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1/3), heightDimension: .fractionalHeight(1)))
        item.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalWidth(1/3)), subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
        return UICollectionViewCompositionalLayout(section: section)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.collectionView?.register(ThumbnailCell.self, forCellWithReuseIdentifier: reuseIdentifier)

        navigationItem.rightBarButtonItem = closeButton
        if #unavailable(iOS 26.0) {
            closeButton.tintColor = .black
        }
    }

    @objc func close() {
        self.dismiss(animated: true, completion: nil)
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return itemsDataSource.itemCount()
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! ThumbnailCell

        let item = itemsDataSource.provideGalleryItem((indexPath as NSIndexPath).row)

        switch item {

        case .image(let fetchImageBlock):

            fetchImageBlock() { image in

                if let image = image {

                    cell.imageView.image = image
                }
            }

        case .video(let fetchImageBlock, _):

            fetchImageBlock() { image in

                if let image = image {

                    cell.imageView.image = image
                }
            }

        case .custom(let fetchImageBlock, _):

            fetchImageBlock() { image in

                if let image = image {

                    cell.imageView.image = image
                }
            }
        }

        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onItemSelected?((indexPath as NSIndexPath).row)
        close()
    }
}
