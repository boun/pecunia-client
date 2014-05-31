/**
 * Copyright (c) 2008, 2014, Pecunia Project. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; version 2 of the
 * License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301  USA
 */

#import "PecuniaSectionItem.h"
#include "Transfer.h"

@class MCEMTreeController;
@class SynchronousScrollView;
@class PecuniaSplitView;
@class TimeSliceManager;
@class BWGradientBox;
@class EDSideBar;
@class CategoryView;
@class DockIconController;
@class ComTraceHelper;
@class BankAccount;
@class BankStatement;

@class HomeScreenController;
@class StatementsOverviewController;
@class CategoryAnalysisWindowController;
@class CategoryRepWindowController;
@class CategoryDefWindowController;
@class CategoryPeriodsWindowController;
@class TransfersController;
@class StandingOrderController;
@class DebitsController;
@class CategoryHeatMapController;
@class BSSelectWindowController;

@class INAppStoreWindow;

@interface BankingController : NSObject
{
@private
    IBOutlet INAppStoreWindow      *mainWindow;

    IBOutlet EDSideBar              *sidebar;
    IBOutlet NSTabView              *mainTabView;
    IBOutlet MCEMTreeController     *categoryController;
    IBOutlet SynchronousScrollView  *accountsScrollView;
    IBOutlet PecuniaSplitView       *mainVSplit;
    IBOutlet NSArrayController      *assignPreviewController;
    IBOutlet TimeSliceManager       *timeSlicer;
    IBOutlet NSSegmentedControl     *catActions;
    IBOutlet NSImageView            *lockImage;
    IBOutlet NSTextField            *earningsField;
    IBOutlet NSTextField            *spendingsField;
    IBOutlet NSTextField            *earningsFieldLabel;
    IBOutlet NSTextField            *spendingsFieldLabel;
    IBOutlet NSView                 *sectionPlaceholder;
    IBOutlet NSView                 *rightPane;
    IBOutlet NSButton               *refreshButton;
    IBOutlet ComTraceHelper         *comTracePanel;
    IBOutlet NSButton               *decreaseFontButton;
    IBOutlet NSButton               *increaseButton;

    IBOutlet NSMenuItem *developerMenu;
    IBOutlet NSMenuItem *comTraceMenuItem;

    IBOutlet NSButton *toggleDetailsButton;

    NSManagedObjectContext *managedObjectContext;

    NSMutableDictionary    *mainTabItems;
    NSUInteger             newStatementsCount;

    HomeScreenController             *homeScreenController;
    StatementsOverviewController     *overviewController;
    CategoryAnalysisWindowController *categoryAnalysisController;
    CategoryRepWindowController      *categoryReportingController;
    CategoryDefWindowController      *categoryDefinitionController;
    CategoryPeriodsWindowController  *categoryPeriodsController;
    TransfersController              *transfersController;
    StandingOrderController          *standingOrderController;
    DebitsController                 *debitsController;
    CategoryHeatMapController        *heatMapController;
    BSSelectWindowController         *selectWindowController;
}

@property (strong) IBOutlet CategoryView *accountsView;
@property (strong) IBOutlet NSMenuItem   *toggleDetailsPaneItem;

@property (nonatomic, copy) NSDecimalNumber          *saveValue;
@property (nonatomic, strong) DockIconController     *dockIconController;

@property (nonatomic, assign) BOOL showBalances;
@property (nonatomic, assign) BOOL showRecursiveStatements;
@property (nonatomic, assign) BOOL showDetailsPane;
@property (nonatomic, assign) BOOL shuttingDown;

- (IBAction)addAccount: (id)sender;
- (IBAction)showProperties: (id)sender;
- (IBAction)deleteAccount: (id)sender;
- (IBAction)editPreferences: (id)sender;

- (IBAction)enqueueRequest: (id)sender;
- (IBAction)editBankUsers: (id)sender;
- (IBAction)export: (id)sender;
- (IBAction)import: (id)sender;

- (IBAction)startLocalTransfer: (id)sender;
- (IBAction)startEuTransfer: (id)sender;
- (IBAction)startSepaTransfer: (id)sender;
- (IBAction)startInternalTransfer: (id)sender;
- (void)startTransferOfType: (TransferType)type fromAccount: (BankAccount *)account statement: (BankStatement *)statement;
- (void)createTemplateFromStatement: (BankStatement *)statement;

- (IBAction)splitPurpose: (id)sender;

- (void)insertCategory: (id)sender;
- (void)deleteCategory: (id)sender;
- (IBAction)manageCategories: (id)sender;

- (IBAction)deleteStatement: (id)sender;
- (IBAction)splitStatement: (id)sender;
- (IBAction)addStatement: (id)sender;
- (IBAction)showLicense: (id)sender;
- (IBAction)showConsole:(id)sender;
- (IBAction)resetIsNewStatements: (id)sender;

- (IBAction)getAccountBalance: (id)sender;


- (IBAction)updateStatementBalances:(id)sender;
- (IBAction)accountMaintenance: (id)sender;
- (IBAction)updateSupportedTransactions:(id)sender;

- (IBAction)showAboutPanel: (id)sender;
- (IBAction)toggleDetailsPane: (id)sender;
- (IBAction)toggleFeature: (id)sender;

- (IBAction)deleteAllData: (id)sender;
- (IBAction)generateData: (id)sender;

- (IBAction)creditCardSettlements: (id)sender;

- (void)statementsNotification: (NSNotification *)notification;
- (Category *)getBankingRoot;
- (void)updateNotAssignedCategory;
- (void)requestFinished: (NSArray *)resultList;
- (BOOL)requestRunning;

- (Category *)currentSelection;
- (void)repairCategories;
- (void)setRestart;
- (void)syncAllAccounts;
- (void)publishContext;
- (void)updateUnread;
- (void)updateStatusbar;
- (BOOL)checkForUnhandledTransfersAndSend;
- (void)migrate;
- (void)checkBalances: (NSArray *)resultList;
- (void)setHBCIAccounts;

+ (BankingController *)controller;

@end
