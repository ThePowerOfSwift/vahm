//
//  OpenCvBlinkDetection.h
//  CVOCV
//
//  Created by Christian Fischl on 30.10.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "OpenCV/cv.h"

@interface OpenCvBlinkDetection : NSObject {

}

- (BOOL) is_eye_pair;
- (BOOL) locateEye;
- (BOOL) isBlink;
- (int) getConnectedComponents;
- (IplImage*) pushFrame:(IplImage*)frame;

@end
