//
//  ABBorderGrey.swift
//  Pods
//
//  Created by Jason on 2017/5/22.
//
//

import UIKit

class ABBorderGrey: UIView {

    var imageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let bundle = Bundle(for: ABStartIndicator.self)
        let image = UIImage(named: "BorderLineGray", in: bundle, compatibleWith: nil)
        self.contentMode = .scaleAspectFit

        self.backgroundColor = UIColor(patternImage: image!)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
}
