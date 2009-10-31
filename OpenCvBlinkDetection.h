//
//  OpenCvBlinkDetection.h
//  CVOCV
//
//  Created by Christian Fischl on 30.10.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "cv.h"

@interface OpenCvBlinkDetection : NSObject {

}

- (BOOL) is_eye_pair;
- (int) locateEye;
- (int) isBlink;
- (int) getConnectedComponents;
- (BOOL) pushFrame:(IplImage*)frame;

@end
