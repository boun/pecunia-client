//
//  TransferTemplateController.m
//  Pecunia
//
//  Created by Frank Emminghaus on 26.09.10.
//  Copyright 2010 Frank Emminghaus. All rights reserved.
//

#import "TransferTemplateController.h"
#import "TransferTemplate.h"
#import "MOAssistant.h"
#import "HBCIClient.h"
#import "Transfer.h"
#import "Country.h"

@interface TransferTemplateController(private)
-(void)countryChanged:(id)sender;
-(BOOL)checkTemplate:(TransferTemplate*)t;
-(void)closeEditAnimate:(BOOL)animate;
-(void)openEditAnimate:(BOOL)animate;
-(void)add:(id)sender;
-(void)delete:(id)sender;
-(void)edit:(id)sender;
@end

@implementation TransferTemplateController

-(id)init
{
	self = [super initWithWindowNibName:@"TransferTemplates"];
	context = [[MOAssistant assistant ] context];
	return self;
}

-(void)awakeFromNib
{
	[templateController setManagedObjectContext:context ];
	
	// sort descriptor for transactions view
	NSSortDescriptor	*sd = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
	NSArray				*sds = [NSArray arrayWithObject:sd];
	[countryController setSortDescriptors: sds ];

	NSDictionary *countries = [[HBCIClient hbciClient ] countries ];
	[countryController setContent:[countries allValues ] ];
	// sort descriptor for transactions view
	[countryController rearrangeObjects ];
	
	currentView = standardView;
	subViewPos.x = 18; subViewPos.y = 14;
	
	[self closeEditAnimate:NO ];

}

-(BOOL)checkTemplate:(TransferTemplate*)template
{
	TransferType transferType = [template.type intValue ];
	int res;
	
	if(template.remoteName == nil) {
		NSRunAlertPanel(NSLocalizedString(@"AP1", @"Missing data"), 
						NSLocalizedString(@"AP8", @"Please enter a receiver"),
						NSLocalizedString(@"ok", @"Ok"), nil, nil);
		return NO;
	}
	// do not check remote account for EU transfers, instead IBAN
	if(transferType != TransferTypeEU && transferType != TransferTypeSEPA) {
		if(template.remoteAccount == nil) {
			NSRunAlertPanel(NSLocalizedString(@"AP1", @"Missing data"),
							NSLocalizedString(@"AP9", @"Please enter an account number"),
							NSLocalizedString(@"ok", @"Ok"), nil, nil);
			return NO;
		}
	} else {
		// EU or SEPA transfer
		if(template.remoteIBAN == nil) {
			NSRunAlertPanel(NSLocalizedString(@"AP1", @"Missing data"),
							NSLocalizedString(@"AP24", @"Please enter a valid IBAN"),
							NSLocalizedString(@"ok", @"Ok"), nil, nil);
			return NO;
		}
		// check IBAN
		if([[HBCIClient hbciClient ] checkIBAN: template.remoteIBAN ] == NO) {
			NSRunAlertPanel(NSLocalizedString(@"wrong_input", @"Wrong input"), 
							NSLocalizedString(@"AP26", @"IBAN is not valid"),
							NSLocalizedString(@"retry", @"Retry"), nil, nil);
			return NO;
		}
	}
	
	if(transferType == TransferTypeSEPA) {
		if(template.remoteBIC == nil) {
			NSRunAlertPanel(NSLocalizedString(@"AP1", @"Missing data"), 
							NSLocalizedString(@"AP25", @"Please enter valid bank identification code (BIC)"),
							NSLocalizedString(@"ok", @"Ok"), nil, nil);
			return NO;
		}
	}
		
	// verify account and bank information
	if(transferType != TransferTypeEU && transferType != TransferTypeSEPA) {
		// verify accounts, but only for available countries
		if([template.remoteCountry caseInsensitiveCompare: @"de" ] == NSOrderedSame ||
		   [template.remoteCountry caseInsensitiveCompare: @"at" ] == NSOrderedSame ||
		   [template.remoteCountry caseInsensitiveCompare: @"ch" ] == NSOrderedSame ||
		   [template.remoteCountry caseInsensitiveCompare: @"ca" ] == NSOrderedSame) {
			
			res = [[HBCIClient hbciClient ] checkAccount: template.remoteAccount 
												 forBank: template.remoteBankCode 
											   inCountry: template.remoteCountry ];
			
			if(res == NO) {
				NSRunAlertPanel(NSLocalizedString(@"wrong_input", @"Wrong input"), 
								NSLocalizedString(@"AP13", @"Account number is not valid"),
								NSLocalizedString(@"retry", @"Retry"), nil, nil);
				return NO;
			}
		}
	}
	
	if (template.currency == nil || [template.currency length ] == 0) {
		template.currency = @"EUR";
	}
	template.currency = [template.currency uppercaseString ];
	
	return YES;
}

-(void)windowWillClose:(NSNotification *)notification
{
	
}

-(BOOL)windowShouldClose:(id)sender
{
	return YES;
}

-(void)delete:(id)sender
{
	int res = NSRunAlertPanel(NSLocalizedString(@"AP104", @""), 
							  NSLocalizedString(@"AP105", @""),
							  NSLocalizedString(@"yes", @"Yes"), 
							  NSLocalizedString(@"no", @"No"), nil);
	if (res == NSAlertDefaultReturn) {
		[templateController remove:sender ];
	}
}

-(void)closeEditAnimate:(BOOL)animate
{
	NSRect frame = [[self window ] frame ];
	[boxView setHidden: YES ];
	frame.size.height -= 300;
	frame.origin.y += 300;
	[scrollView setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable ];
	[segmentView setAutoresizingMask:NSViewMinYMargin ];
	[[self window ] setFrame:frame display:YES animate:animate ];
	[scrollView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable ];
	[segmentView setAutoresizingMask:NSViewMaxYMargin ];
	[tableView setEnabled: YES ];
	editMode = NO;
}

-(void)openEditAnimate:(BOOL)animate
{
	NSRect frame = [[self window ] frame ];
	frame.size.height += 300;
	frame.origin.y -= 300;
	[scrollView setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable ];
	[segmentView setAutoresizingMask:NSViewMinYMargin ];
	[[self window ] setFrame:frame display:YES animate:animate ];
	[boxView setHidden: NO ];
	[scrollView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable ];
	[segmentView setAutoresizingMask:NSViewMaxYMargin ];
	[tableView setEnabled: NO ];
	editMode = YES;
}

-(void)edit:(id)sender
{
	if (editMode == NO) {
		[cancelButton setHidden:YES ];
		[self openEditAnimate:YES ];
	}
}

-(void)add:(id)sender
{
	TransferTemplate *template = [NSEntityDescription insertNewObjectForEntityForName:@"TransferTemplate" inManagedObjectContext:context ];
	template.name = NSLocalizedString(@"AP106", @"");
	template.currency = @"EUR";
	[templateController addObject:template ];
	
	// now find out index of added item
	int idx = 0;
	for(TransferTemplate *tmp in [templateController arrangedObjects ]) {
		if (tmp == template) {
			break;
		} else idx++;
	}
	[templateController setSelectionIndex:idx ];
	[self edit:sender ];
	[cancelButton setHidden:NO ];
}

-(IBAction)finished:(id)sender
{
	NSArray *sel = [templateController selectedObjects ];
	if (sel == nil || [sel count ] == 0) return;
	TransferTemplate *template = [sel lastObject ];
	if([self checkTemplate:template ]) [self closeEditAnimate:YES ];
}

-(IBAction)cancel:(id)sender
{
	[templateController remove:self ];
	[self closeEditAnimate:YES ];
}

-(IBAction)segButtonPressed:(id)sender
{
	int clickedSegment = [sender selectedSegment];
    int clickedSegmentTag = [[sender cell] tagForSegment:clickedSegment];
	switch(clickedSegmentTag) {
		case 0: [self add: sender ]; break;
		case 1: [self delete: sender ]; break;
		case 2: [self edit: sender ]; break;
		default: return;
	}
}

-(void)toggleCountryFieldsForType: (TransferType)type
{
    BOOL hidden = (type == TransferTypeSEPA);
    
    NSArray *subviews = [currentView subviews ];
    for(NSView *view in subviews) {
        if ([view tag ] >= 100) [view setHidden:hidden ];
    }
}


- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSArray *sel = [templateController selectedObjects ];
	if (sel == nil || [sel count ] == 0) return;
	TransferTemplate *template = [sel lastObject ];
	if (([template.type intValue ] == TransferTypeEU || [template.type intValue ] == TransferTypeSEPA) && currentView == standardView) {
		[boxView replaceSubview:standardView with:euView ];
		[euView setFrameOrigin:subViewPos ];
		currentView = euView;
        [self toggleCountryFieldsForType: [template.type intValue ] ];
	}
	if (([template.type intValue ] != TransferTypeEU || [template.type intValue ] != TransferTypeSEPA) && currentView == euView) {
		[boxView replaceSubview:euView with:standardView ];
		currentView = standardView;
	}
	
	if ([template.type intValue ] == TransferTypeEU) {
		NSArray *countries = [countryController arrangedObjects ];
		int idx=0;
		for(Country *country in countries) {
			if ([country.code isEqualToString: template.remoteCountry ]) {
				[countryController setSelectionIndex:idx ];
				break;
			} else idx++;
		}
	}
}

-(IBAction)countryChanged:(id)sender
{
	Country *country = [[countryController selectedObjects ] lastObject ];
	if (country) {
		NSArray *sel = [templateController selectedObjects ];
		if (sel == nil || [sel count ] == 0) return;
		TransferTemplate *template = [sel lastObject ];
		template.remoteCountry = country.code;
	}
}

@end
