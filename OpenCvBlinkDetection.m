//
//  OpenCvBlinkDetection.m
//  CVOCV
//
//  Created by Christian Fischl on 30.10.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//
#define STAGE_INIT		1
#define STAGE_TRACKING	2
#define TPL_WIDTH 		32//16
#define TPL_HEIGHT 		24//12
#define WIN_WIDTH		TPL_WIDTH * 2
#define WIN_HEIGHT		TPL_HEIGHT * 2
#define TM_THRESHOLD	0.2

#import "OpenCvBlinkDetection.h"
#import "Growl/Growl.h"
#import "Growl/GrowlApplicationBridge.h"

static IplImage		* frame, * gray, * prev, * diff, * tpl;
static CvMemStorage	* storage;
static IplConvKernel	* kernel;
static CvSeq			* comp = 0;
static CvRect			window, eye;
static int				key, nc, found; 
static int				stage = STAGE_INIT;
static int				delay;

@implementation OpenCvBlinkDetection

-(id)init
{
	CvSize framesize = cvSize(320, 240);
	storage = cvCreateMemStorage(0);
	if (!storage)
		return NULL;
	
	kernel = cvCreateStructuringElementEx(3, 3, 1, 1, CV_SHAPE_CROSS, NULL);
	gray   = cvCreateImage(framesize, 8, 1);
	
	prev   = cvCreateImage(framesize, 8, 1);
	diff   = cvCreateImage(framesize, 8, 1);
	tpl	   = cvCreateImage(cvSize(TPL_WIDTH, TPL_HEIGHT), 8, 1);
	
	if (!kernel || !gray || !prev || !diff || !tpl)
		return NULL;
	
//	gray->origin  = frame->origin;
//	prev->origin  = frame->origin;
//	diff->origin  = frame->origin;
	
	NSLog(@"init called");
	return self;
}

-(IplImage*)pushFrame:(IplImage*)_frame
{
	IplImage *texImage = cvCreateImage(cvSize(320, 240), IPL_DEPTH_8U, 3);
	cvCopy(_frame, texImage, 0);
	frame = _frame;

	NSLog(@"pushFrame called");
	
	if (delay > 0) {
		delay--;
		return texImage;
	}
	
	frame->origin = 0;
	
	if (stage == STAGE_INIT)
		window = cvRect(0, 0, frame->width, frame->height);
	
	cvCvtColor(frame, gray, CV_BGR2GRAY);
	
	
	nc = [self getConnectedComponents];
	NSLog(@"Components: %i", nc);
	
	if (stage == STAGE_INIT && [self is_eye_pair]) 
	{
		delay = 5;
		cvSetImageROI(gray, eye);
		cvCopy(gray, tpl, NULL);
		cvResetImageROI(gray);
		
		stage = STAGE_TRACKING;
	}
	
	if (stage == STAGE_TRACKING && delay == 0) 
	{
		
		found = [self locateEye];
		
		if (!found)
			stage = STAGE_INIT;
		
		
		if ([self isBlink])
		{
			NSLog(@"BLINK!");
				
					[GrowlApplicationBridge notifyWithTitle:@"Blink Detection"
												description:@"BLINK! :)" 
										   notificationName:@"Blink"
												   iconData:nil
												   priority:1
												   isSticky:NO
											   clickContext:nil];
		}
	}
	

	cvRectangle(texImage, cvPoint(eye.x, eye.y), cvPoint(eye.x + eye.width, eye.y + eye.height), CV_RGB(255,0,0), 1, 8, 0);
	
	prev = (IplImage*)cvClone(gray);
	return texImage;
}


//are the 2 found components possibly eyes?
- (BOOL)is_eye_pair
{

	
	if (comp == 0 || nc != 2)
	{
		return FALSE;
	}
	
	
	CvRect r1 = cvBoundingRect(comp, 1);
	comp = comp->h_next;
	
	if (comp == 0)
		return FALSE;
	
	CvRect r2 = cvBoundingRect(comp, 1);
	
	/* the width of the components are about the same */
	if (abs(r1.width - r2.width) >= 5)
		return FALSE;
	
	/* the height f the components are about the same */
	if (abs(r1.height - r2.height) >= 5)
		return FALSE;
	
	/* vertical distance is small */
	if (abs(r1.y - r2.y) >= 5)
		return FALSE;
	
	/* reasonable horizontal distance, based on the components' width */
	int dist_ratio = abs(r1.x - r2.x) / r1.width;
	if (dist_ratio < 2 || dist_ratio > 5)
		return FALSE;
	
	/* get the centroid of the 1st component */
	CvPoint point = cvPoint(
							r1.x + (r1.width / 2),
							r1.y + (r1.height / 2)
							);
	
	/* return eye boundaries */
	eye = cvRect(point.x - (TPL_WIDTH / 2), point.y - (TPL_HEIGHT / 2), TPL_WIDTH, TPL_HEIGHT);
	
	return TRUE;

}

//check if template is in predefined searchwindow by using cvMatchTemplate
- (BOOL) locateEye
{

	double minval, maxval;
	CvPoint point = cvPoint(eye.x + (eye.width)/2, eye.y + (eye.height)/2);
	CvRect win = cvRect(point.x - WIN_WIDTH / 2, point.y - WIN_HEIGHT / 2, WIN_WIDTH, WIN_HEIGHT);
	CvPoint minloc, maxloc;
	
	if (win.x < 0)
		win.x = 0;
	if (win.y < 0)
		win.y = 0;
	if (win.x + win.width > gray->width)
		win.x = gray->width - win.width;
	if (win.y + win.height > gray->height)
		win.y = gray->height - win.height;
	
	int w  = win.width  - tpl->width  + 1;
	int h  = win.height - tpl->height + 1;
	IplImage* tm = cvCreateImage(cvSize(w, h), IPL_DEPTH_32F, 1);
	
	cvSetImageROI(gray, win);
	
	cvMatchTemplate(gray, tpl, tm, CV_TM_SQDIFF_NORMED);
	cvMinMaxLoc(tm, &minval, &maxval, &minloc, &maxloc, 0);
	
	cvResetImageROI(gray);
	cvReleaseImage(&tm);
	
	NSLog(@"minval: %f maxval: %f",minval, maxval );

	
	if (minval > TM_THRESHOLD) {
		return FALSE; //kommt das vor?
	}
	
	window = win;
	
	eye = cvRect(win.x + minloc.x, win.y + minloc.y, TPL_WIDTH, TPL_HEIGHT);
	
	return TRUE;
	
}

//Is the component in the search window (and at the eye's centroid)?
- (BOOL) isBlink
{
	
	if (comp == 0 || nc != 1)
		return FALSE;
	
	CvRect r1 = cvBoundingRect(comp, 1);
	
	/* component is within the search window */
	if (r1.x < window.x)
		return FALSE;
	if (r1.y < window.y)
		return FALSE;
	if (r1.x + r1.width > window.x + window.width)
		return FALSE;
	if (r1.y + r1.height > window.y + window.height)
		return FALSE;
	
	/* get the centroid of eye */
	CvPoint pt = cvPoint(
						 eye.x + eye.width / 2,
						 eye.y + eye.height / 2
						 );
	
	/* component is located at the eye's centroid */
	if (pt.x <= r1.x || pt.x >= r1.x + r1.width)
		return FALSE;
	if (pt.y <= r1.y || pt.y >= r1.y + r1.height)
		return FALSE;
	
	return TRUE;

}

- (int) getConnectedComponents
{
	//nc = get_connected_components(gray, prev, window, &comp);
	
	IplImage* _diff;
	cvZero(diff);
	
	cvSetImageROI(gray, window);
	cvSetImageROI(prev, window);
	cvSetImageROI(diff, window);
	
	cvSub(gray, prev, diff, NULL);
	cvThreshold(diff, diff, 5, 255, CV_THRESH_BINARY);
	cvMorphologyEx(diff, diff, NULL, kernel, CV_MOP_OPEN, 1);
	
	cvResetImageROI(gray);
	cvResetImageROI(prev);
	cvResetImageROI(diff);
	
	_diff = (IplImage*)cvClone(diff);
	
	int nc = cvFindContours(_diff, storage, &comp, sizeof(CvContour), CV_RETR_CCOMP, CV_CHAIN_APPROX_SIMPLE, cvPoint(0, 0));
	cvClearMemStorage(storage);
	cvReleaseImage(&_diff);
		
	return nc;
}


@end
