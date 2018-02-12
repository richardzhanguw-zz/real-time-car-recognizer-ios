//
//  ViewController.swift
//  Car Recognizer
//
//  Created by Richard Zhang on 2018-02-09.
//  Copyright © 2018 Richard Zhang. All rights reserved.
//

import UIKit
import ARKit
import SceneKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {
    
    var arView: ARSCNView!
    var requests = [VNRequest]()
    var mostRecentLocation : String = "none"
    
    let customDispatchQueue = DispatchQueue(label: "Custom Dispatch Queue")
    let arSceneConfig = ARWorldTrackingConfiguration()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        arView = ARSCNView(frame: CGRect(x: 0, y: self.view.safeAreaInsets.top, width: self.view.frame.width, height: self.view.frame.height - self.view.safeAreaInsets.top - self.view.safeAreaInsets.bottom))
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(arView)
        arView.delegate = self
        arView.scene = SCNScene()
        arSceneConfig.planeDetection = .horizontal
        guard let mlModel = try? VNCoreMLModel(for: CarRecognition().model) else {
            fatalError("Model does not exist")
        }
        let request = VNCoreMLRequest(model: mlModel, completionHandler: coreMLcompletionHandler)
        request.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
        requests = [request]
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
            let worldCoord : SCNVector3 = SCNVector3Make(0.0 ,0.0, -0.2)
            let node : SCNNode = self.createLocationNode(withLocationName: self.mostRecentLocation)
            self.arView.scene.rootNode.addChildNode(node)
            node.position = worldCoord
        })
        refreshScreen()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        arView.session.run(arSceneConfig)
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView.session.pause()
    }
    
    func refreshScreen() {
        customDispatchQueue.async {
            self.refreshScreen()
            let pixelBuffer : CVPixelBuffer? = (self.arView.session.currentFrame?.capturedImage)
            let ciImage = pixelBuffer == nil ? nil : CIImage(cvPixelBuffer: pixelBuffer!)
            let imgReqHandler = ciImage == nil ? nil : VNImageRequestHandler(ciImage: ciImage!, options: [:])
            if let reqHandler = imgReqHandler{
                do {
                    try reqHandler.perform(self.requests)
                } catch {
                    print(error)
                }
            }
        }
    }
    
    func createLocationNode(withLocationName locationName : String) -> SCNNode {
        let depth = CGFloat(0.02)
        let text = SCNText(string: locationName, extrusionDepth: depth)
        let wrapperBubbleNode = SCNNode()
        text.chamferRadius = CGFloat(0.02)
        text.alignmentMode = kCAAlignmentCenter
        text.font = UIFont(name: "Courier-Bold", size: 0.1)
        let textNode = SCNNode(geometry: text)
        textNode.scale = SCNVector3Make(0.1, 0.1, 0.1)
        textNode.pivot = SCNMatrix4MakeTranslation( (text.boundingBox.max.x - text.boundingBox.min.x)/2, text.boundingBox.min.y, Float(depth))
        wrapperBubbleNode.addChildNode(textNode)
        return wrapperBubbleNode
    }
    
    func coreMLcompletionHandler(request: VNRequest, error: Error?) {
        let classification = request.results == nil ? nil : request.results![0] as? VNClassificationObservation
        if let classification = classification {
            DispatchQueue.main.async {
                let firstGuess = classification.identifier.components(separatedBy: ",")
                self.mostRecentLocation = firstGuess[0]
            }
        } else {
            if let errorThrown = error {
                fatalError(errorThrown.localizedDescription)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
    }
}

