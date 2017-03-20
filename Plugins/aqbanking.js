// JS banking plugin for Pecunia
// Author: Benedikt Elser
//
// Plugin to read statements from aquabanking


// Plugin details used to manage usage. Name and description are mandatory.
var name = "pecunia.plugin.aquabanking";
var author = "Benedikt Elser";
var description = "AqBanking Legacy Connector"; // Short string for plugin selection.
var homePage = "http://pecuniabanking.de";
var license = "CC BY-NC-ND 4.0 - http://creativecommons.org/licenses/by-nc-nd/4.0/deed.de";
var version = "1.0";

// Optionial function to support auto account type determination.
function canHandle(account, bankCode) {
    logger.logDebug("Can handle " + account + " " + bankCode);
    if (bankCode != "70080000")
        return false;
    
    return true;
}

function getStatements(user, bankCode, password, from, to, accounts) {
    var url = "http://localhost:8000/transactions?a=b";
    if (from)
        url += ("&from_date=" + Math.floor(new Date(from).getTime() / 1000));
    if (to)
        url += ("&to_date=" + Math.floor(new Date(to).getTime() / 1000));
    if (accounts)
        url += ("&accounts=" + accounts);
    webClient.callback = navigationCallback;
    webClient.URL = url;
    logger.logDebug("url " + url);

    return true;
}

function fixDates(results) {
	for (var account in results) {
		results[account].lastSettleDate = new Date( results[account].lastSettleDate );
		for (var transaction in results[account].statements) {
			results[account].statements[transaction].date = new Date( results[account].statements[transaction].date );
			results[account].statements[transaction].valutaDate = new Date( results[account].statements[transaction].valutaDate );
		}
	}
	return results;
}

function navigationCallback() {
	var text = webClient.mainFrameDocument.body.innerText;
	var results = JSON.parse(text, JSON.dateParser);

	results = fixDates(results);
    logger.logDebug("Navigation Callback: " + results[0].lastSettleDate)
    webClient.callback = null; // Unregister ourselve. We are done.
    webClient.resultsArrived(results);
    logger.logDebug("Plugin invocation done");
}

true;
