//
//  ABVideoRangeSlider.swift
//  selfband
//
//  Created by Oscar J. Irun on 26/11/16.
//  Copyright © 2016 appsboulevard. All rights reserved.
//

import UIKit

@objc public protocol ABVideoRangeSliderDelegate: class {
    func didChangeValue(videoRangeSlider: ABVideoRangeSlider, startTime: Float64, endTime: Float64)
    func indicatorDidChangePosition(videoRangeSlider: ABVideoRangeSlider, position: Float64)
    
    @objc optional func sliderGesturesBegan()
    @objc optional func sliderGesturesEnded()
}

public class ABVideoRangeSlider: UIView, UIGestureRecognizerDelegate {

    private enum DragHandleChoice {
        case start
        case end
    }
    
    public weak var delegate: ABVideoRangeSliderDelegate? = nil

    var startIndicator      = ABStartIndicator()
    var endIndicator        = ABEndIndicator()
    var topLine             = ABBorder()
    var bottomLine          = ABBorderGrey()
    var progressIndicator   = ABProgressIndicator()
    var draggableView       = UIView()
    var grayTimeline        = ABBorderGrey()
    var thumbnailView       = UIView()

    public var startTimeView       = ABTimeView()
    public var endTimeView         = ABTimeView()

    let thumbnailsManager   = ABThumbnailsManager()
    var duration: Float64   = 0.0
    var videoURL            = URL(fileURLWithPath: "")

    var progressPercentage: CGFloat = 0         // Represented in percentage
    var startPercentage: CGFloat    = 0         // Represented in percentage
    var endPercentage: CGFloat      = 100       // Represented in percentage

    let progressBarHeight: CGFloat = 20
    let topBorderHeight: CGFloat      = 20
    let bottomBorderHeight: CGFloat   = 20
    let progressWrapHeight: CGFloat = 40

    let indicatorWidth: CGFloat = 20.0

    public var minSpace: Float = 1              // In Seconds
    public var maxSpace: Float = 0              // In Seconds
    
    public var isProgressIndicatorSticky: Bool = false
    public var isProgressIndicatorDraggable: Bool = true
    
    var isUpdatingThumbnails = false
    var isReceivingGesture: Bool = false
    
    public enum ABTimeViewPosition{
        case top
        case bottom
    }

    override public func awakeFromNib() {
        super.awakeFromNib()
        self.setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    private func setup(){
        self.isUserInteractionEnabled = true

        self.backgroundColor = UIColor.white
        
        self.addSubview(grayTimeline)
        
        // Setup Start Indicator
        let startDrag = UIPanGestureRecognizer(target:self,
                                               action: #selector(startDragged(recognizer:)))

        startIndicator = ABStartIndicator(frame: CGRect(x: 0,
                                                        y: -topBorderHeight,
                                                        width: indicatorWidth,
                                                        height: progressWrapHeight + bottomBorderHeight + topBorderHeight))
        startIndicator.layer.anchorPoint = CGPoint(x: 0.5, y: 0.8)
        startIndicator.addGestureRecognizer(startDrag)
        
        self.addSubview(startIndicator)

        // Setup End Indicator

        let endDrag = UIPanGestureRecognizer(target:self,
                                             action: #selector(endDragged(recognizer:)))

        endIndicator = ABEndIndicator(frame: CGRect(x: 0,
                                                    y: -topBorderHeight,
                                                    width: indicatorWidth,
                                                    height: progressWrapHeight + bottomBorderHeight + topBorderHeight))
        endIndicator.layer.anchorPoint = CGPoint(x: 0.5, y: 0.2)
        endIndicator.addGestureRecognizer(endDrag)
        
        self.addSubview(endIndicator)


        // Setup Top and bottom line

        topLine = ABBorder(frame: CGRect(x: 0,
                                         y: (progressWrapHeight - topBorderHeight)/2,
                                         width: indicatorWidth,
                                         height: topBorderHeight))
        self.addSubview(topLine)

        bottomLine = ABBorderGrey(frame: CGRect(x: 0,
                                            y: progressWrapHeight,
                                            width: indicatorWidth,
                                            height: bottomBorderHeight))
        self.addSubview(bottomLine)


        self.addObserver(self,
                         forKeyPath: "bounds",
                         options: NSKeyValueObservingOptions(rawValue: 0),
                         context: nil)

        // Setup Progress Indicator

//        let progressDrag = UIPanGestureRecognizer(target:self,
//                                                  action: #selector(progressDragged(recognizer:)))

        progressIndicator = ABProgressIndicator(frame: CGRect(x: 0,
                                                              y: -topBorderHeight,
                                                              width: 10,
                                                              height: progressWrapHeight + bottomBorderHeight + topBorderHeight))
//        progressIndicator.addGestureRecognizer(progressDrag)
//        self.addSubview(progressIndicator)
        
        // Thumbnail View
        thumbnailView = UIView(frame: CGRect(x: 0, y: progressWrapHeight + 40, width: self.frame.width, height: progressWrapHeight * (3/2)))
        thumbnailView.backgroundColor = UIColor.gray
        self.addSubview(thumbnailView)

        // Setup Draggable View

        let viewDrag = UIPanGestureRecognizer(target:self,
                                              action: #selector(viewDragged(recognizer:)))

        draggableView.addGestureRecognizer(viewDrag)
        self.draggableView.backgroundColor = .clear
        self.addSubview(draggableView)
        self.sendSubview(toBack: draggableView)

        // Setup time labels

        startTimeView = ABTimeView(size: CGSize(width: 110, height: 30))
        startTimeView.layer.anchorPoint = CGPoint(x: -0.1, y: -0.21)
        self.addSubview(startTimeView)

        endTimeView = ABTimeView(size: CGSize(width: 110, height: 30))
        endTimeView.layer.anchorPoint = CGPoint(x: 1.1, y: -1.7)
        self.addSubview(endTimeView)
        
    }

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "bounds"{
            self.updateThumbnails()
        }
    }

    // MARK: Public functions

    public func setProgressIndicatorImage(image: UIImage){
        self.progressIndicator.imageView.image = image
    }

    public func hideProgressIndicator(){
        self.progressIndicator.isHidden = true
    }

    public func showProgressIndicator(){
        self.progressIndicator.isHidden = false
    }

    public func updateProgressIndicator(seconds: Float64){
        if !isReceivingGesture {
            let endSeconds = secondsFromValue(value: self.endPercentage)
            
            if seconds >= endSeconds {
                self.resetProgressPosition()
            } else {
                self.progressPercentage = self.valueFromSeconds(seconds: Float(seconds))
            }

            setNeedsLayout()
        }
    }

    public func setStartIndicatorImage(image: UIImage){
        self.startIndicator.imageView.image = image
    }

    public func setEndIndicatorImage(image: UIImage){
        self.endIndicator.imageView.image = image
    }

    public func setBorderImage(image: UIImage){
        self.topLine.imageView.image = image
        self.bottomLine.imageView.image = image
    }

    public func setTimeView(view: ABTimeView){
        self.startTimeView = view
        self.endTimeView = view
    }

    public func setTimeViewPosition(position: ABTimeViewPosition){
        switch position {
        case .top:

            break
        case .bottom:

            break
        }
    }

    public func setVideoURL(videoURL: URL){
        self.duration = ABVideoHelper.videoDuration(videoURL: videoURL)
        self.videoURL = videoURL
        self.layoutIfNeeded()
        self.updateThumbnails()
    }

    public func updateThumbnails(){
        if !isUpdatingThumbnails{
            self.isUpdatingThumbnails = true
            
            DispatchQueue.main.async {
                _ = self.thumbnailsManager.updateThumbnails(view: self.thumbnailView,
                                                            videoURL: self.videoURL,
                                                            duration: self.duration)
                self.isUpdatingThumbnails = false
            }
        }
    }

    public func setStartPosition(seconds: Float){
        self.startPercentage = self.valueFromSeconds(seconds: seconds)
        setNeedsLayout()
    }

    public func setEndPosition(seconds: Float){
        self.endPercentage = self.valueFromSeconds(seconds: seconds)
        setNeedsLayout()
    }

    // MARK: - Private functions

    // MARK: - Crop Handle Drag Functions
    @objc private func startDragged(recognizer: UIPanGestureRecognizer){
        self.processHandleDrag(
            recognizer: recognizer,
            drag: .start,
            currentPositionPercentage: self.startPercentage,
            currentIndicator: self.startIndicator
        )
    }
    
    @objc private func endDragged(recognizer: UIPanGestureRecognizer){
        self.processHandleDrag(
            recognizer: recognizer,
            drag: .end,
            currentPositionPercentage: self.endPercentage,
            currentIndicator: self.endIndicator
        )
    }

    private func processHandleDrag(
        recognizer: UIPanGestureRecognizer,
        drag: DragHandleChoice,
        currentPositionPercentage: CGFloat,
        currentIndicator: UIView
        ) {
        
        self.updateGestureStatus(recognizer: recognizer)
        
        let translation = recognizer.translation(in: self)
        
        var position: CGFloat = positionFromValue(value: currentPositionPercentage) // self.startPercentage or self.endPercentage
        
        position = position + translation.x
        
        if position < 0 { position = 0 }
        
        if position > self.frame.size.width {
            position = self.frame.size.width
        }

        let positionLimits = getPositionLimits(with: drag)
        position = checkEdgeCasesForPosition(with: position, and: positionLimits.min, and: drag)

        if Float(self.duration) > self.maxSpace && self.maxSpace > 0 {
            if drag == .start {
                if position < positionLimits.max {
                    position = positionLimits.max
                }
            } else {
                if position > positionLimits.max {
                    position = positionLimits.max
                }
            }
        }
        
        recognizer.setTranslation(CGPoint.zero, in: self)
        
        currentIndicator.center = CGPoint(x: position , y: currentIndicator.center.y)
        
        let percentage = currentIndicator.center.x * 100 / self.frame.width
        
        let startSeconds = secondsFromValue(value: self.startPercentage)
        let endSeconds = secondsFromValue(value: self.endPercentage)
        
        self.delegate?.didChangeValue(videoRangeSlider: self, startTime: startSeconds, endTime: endSeconds)
        
        var progressPosition: CGFloat = 0.0
        
        if drag == .start {
            self.startPercentage = percentage
        } else {
            self.endPercentage = percentage
        }
        
        if drag == .start {
            progressPosition = positionFromValue(value: self.startPercentage)
            
        } else {
            if recognizer.state != .ended {
                progressPosition = positionFromValue(value: self.endPercentage)
            } else {
                progressPosition = positionFromValue(value: self.startPercentage)
            }
        }
        
        progressIndicator.center = CGPoint(x: progressPosition , y: progressIndicator.center.y)
        let progressPercentage = progressIndicator.center.x * 100 / self.frame.width
        
        if self.progressPercentage != progressPercentage {
            let progressSeconds = secondsFromValue(value: progressPercentage)
            self.delegate?.indicatorDidChangePosition(videoRangeSlider: self, position: progressSeconds)
        }
        
        self.progressPercentage = progressPercentage
        
        setNeedsLayout()
    }
    
    func progressDragged(recognizer: UIPanGestureRecognizer){
        if !isProgressIndicatorDraggable {
            return
        }
        
        updateGestureStatus(recognizer: recognizer)
        
        let translation = recognizer.translation(in: self)

        let positionLimitStart  = positionFromValue(value: self.startPercentage)
        let positionLimitEnd    = positionFromValue(value: self.endPercentage)

        var position = positionFromValue(value: self.progressPercentage)
        position = position + translation.x

        if position < positionLimitStart {
            position = positionLimitStart
        }

        if position > positionLimitEnd {
            position = positionLimitEnd
        }

        recognizer.setTranslation(CGPoint.zero, in: self)

        progressIndicator.center = CGPoint(x: position , y: progressIndicator.center.y)

        let percentage = progressIndicator.center.x * 100 / self.frame.width

        let progressSeconds = secondsFromValue(value: progressPercentage)

        self.delegate?.indicatorDidChangePosition(videoRangeSlider: self, position: progressSeconds)

        self.progressPercentage = percentage

        setNeedsLayout()
    }

    func viewDragged(recognizer: UIPanGestureRecognizer){
        updateGestureStatus(recognizer: recognizer)
        
        let translation = recognizer.translation(in: self)

        var progressPosition = positionFromValue(value: self.progressPercentage)
        var startPosition = positionFromValue(value: self.startPercentage)
        var endPosition = positionFromValue(value: self.endPercentage)

        startPosition = startPosition + translation.x
        endPosition = endPosition + translation.x
        progressPosition = progressPosition + translation.x

        if startPosition < 0 {
            startPosition = 0
            endPosition = endPosition - translation.x
            progressPosition = progressPosition - translation.x
        }

        if endPosition > self.frame.size.width{
            endPosition = self.frame.size.width
            startPosition = startPosition - translation.x
            progressPosition = progressPosition - translation.x
        }

        recognizer.setTranslation(CGPoint.zero, in: self)

        progressIndicator.center = CGPoint(x: progressPosition , y: progressIndicator.center.y)
        startIndicator.center = CGPoint(x: startPosition , y: startIndicator.center.y)
        endIndicator.center = CGPoint(x: endPosition , y: endIndicator.center.y)

        let startPercentage = startIndicator.center.x * 100 / self.frame.width
        let endPercentage = endIndicator.center.x * 100 / self.frame.width
        let progressPercentage = progressIndicator.center.x * 100 / self.frame.width

        let startSeconds = secondsFromValue(value: startPercentage)
        let endSeconds = secondsFromValue(value: endPercentage)

        self.delegate?.didChangeValue(videoRangeSlider: self, startTime: startSeconds, endTime: endSeconds)

        if self.progressPercentage != progressPercentage{
            let progressSeconds = secondsFromValue(value: progressPercentage)
            self.delegate?.indicatorDidChangePosition(videoRangeSlider: self, position: progressSeconds)
        }

        self.startPercentage = startPercentage
        self.endPercentage = endPercentage
        self.progressPercentage = progressPercentage

        setNeedsLayout()
    }
    
    // MARK: - Drag Functions Helpers
    private func positionFromValue(value: CGFloat) -> CGFloat{
        let position = value * self.frame.size.width / 100
        return position
    }
    
    private func getPositionLimits(with drag: DragHandleChoice) -> (min: CGFloat, max: CGFloat) {
        if drag == .start {
            return (
                positionFromValue(value: self.endPercentage - valueFromSeconds(seconds: self.minSpace)),
                positionFromValue(value: self.endPercentage - valueFromSeconds(seconds: self.maxSpace))
            )
        } else {
            return (
                positionFromValue(value: self.startPercentage + valueFromSeconds(seconds: self.minSpace)),
                positionFromValue(value: self.startPercentage + valueFromSeconds(seconds: self.maxSpace))
            )
        }
    }
    
    private func checkEdgeCasesForPosition(with position: CGFloat, and positionLimit: CGFloat, and drag: DragHandleChoice) -> CGFloat {
        if drag == .start {
            if Float(self.duration) < self.minSpace {
                return 0
            } else {
                if position > positionLimit {
                    return positionLimit
                }
            }
        } else {
            if Float(self.duration) < self.minSpace {
                return self.frame.size.width
            } else {
                if position < positionLimit {
                    return positionLimit
                }
            }
        }
        
        return position
    }
    
    private func secondsFromValue(value: CGFloat) -> Float64{
        return duration * Float64((value / 100))
    }

    private func valueFromSeconds(seconds: Float) -> CGFloat{
        return CGFloat(seconds * 100) / CGFloat(duration)
    }
    
    private func updateGestureStatus(recognizer: UIGestureRecognizer) {
        if recognizer.state == .began {
            
            self.isReceivingGesture = true
            self.delegate?.sliderGesturesBegan?()
            
        } else if recognizer.state == .ended {
            
            self.isReceivingGesture = false
            self.delegate?.sliderGesturesEnded?()
        }
    }
    
    private func resetProgressPosition() {
        self.progressPercentage = self.startPercentage
        let progressPosition = positionFromValue(value: self.progressPercentage)
        progressIndicator.center = CGPoint(x: progressPosition , y: progressIndicator.center.y)
        
        let startSeconds = secondsFromValue(value: self.progressPercentage)
        self.delegate?.indicatorDidChangePosition(videoRangeSlider: self, position: startSeconds)
    }

    // MARK: -

    override public func layoutSubviews() {
        super.layoutSubviews()

        startTimeView.timeLabel.text = self.secondsToFormattedString(totalSeconds: secondsFromValue(value: self.startPercentage))
        endTimeView.timeLabel.text = self.secondsToFormattedString(totalSeconds: secondsFromValue(value: self.endPercentage))

        let startPosition = positionFromValue(value: self.startPercentage)
        let endPosition = positionFromValue(value: self.endPercentage)
        let progressPosition = positionFromValue(value: self.progressPercentage)

        startIndicator.center = CGPoint(x: startPosition, y: startIndicator.center.y)
        endIndicator.center = CGPoint(x: endPosition, y: endIndicator.center.y)
        progressIndicator.center = CGPoint(x: progressPosition, y: progressIndicator.center.y)
        draggableView.frame = CGRect(x: startIndicator.frame.origin.x + startIndicator.frame.size.width,
                                     y: 0,
                                     width: endIndicator.frame.origin.x - startIndicator.frame.origin.x - endIndicator.frame.size.width,
                                     height: progressWrapHeight)


        topLine.frame = CGRect(x: 0,
                               y: (progressWrapHeight - topBorderHeight)/2,
                               width: endIndicator.frame.origin.x + endIndicator.frame.width/2,
                               height: topBorderHeight)

        bottomLine.frame = CGRect(x: 0,
                                  y: (progressWrapHeight - bottomBorderHeight)/2,
                                  width: startIndicator.frame.origin.x + startIndicator.frame.width/2,
                                  height: bottomBorderHeight)

        // Update time view
        startTimeView.center = CGPoint(x: startIndicator.center.x, y: startTimeView.center.y)
        endTimeView.center = CGPoint(x: endIndicator.center.x, y: endTimeView.center.y)
        
        grayTimeline.frame = CGRect(x: 0, y: (progressWrapHeight - progressBarHeight)/2, width: self.frame.width, height: progressBarHeight)
        
        thumbnailView.frame = CGRect(x: 0, y: progressWrapHeight + 20, width: self.frame.width, height: progressWrapHeight * (3/2))
    }


    override public func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let extendedBounds = CGRect(x: -startIndicator.frame.size.width,
                                    y: -topLine.frame.size.height,
                                    width: self.frame.size.width + startIndicator.frame.size.width + endIndicator.frame.size.width,
                                    height: progressWrapHeight + topLine.frame.size.height + bottomLine.frame.size.height)
        return extendedBounds.contains(point)
    }


    private func secondsToFormattedString(totalSeconds: Float64) -> String{
        let hours:Int = Int(totalSeconds.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes:Int = Int(totalSeconds.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds:Int = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
        let centiSeconds = Int(totalSeconds.truncatingRemainder(dividingBy: 1)*100)

        return String(format: "%02i:%02i:%02i.%02i", hours, minutes, seconds, centiSeconds)
    }

    deinit {
      removeObserver(self, forKeyPath: "bounds")
    }
}
