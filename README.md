# ![logo][] FinViz
[logo]: https://finviz.com/favicon_2x.png

Unofficial FinViz PowerShell module, which filters and pulls stock data from [FinViz.com](https://finviz.com/).

<sup>I have no affiliation with [FinViz.com](https://finviz.com/). Any use of their name or logo by me is not intended to imply any association with--or ownership of--[FinViz.com](https://finviz.com/).</sup>

## Functions
Run the following to import the cmdlets:

    Import-Module FinViz.psd1

The functions capture the information via a simple Web Request to [FinViz.com](https://finviz.com/) and parsing the HTML returned. This could, of course, break if FinViz updates their front end, so may not be as reliable as an API call. For an unofficial FinViz API, check out [this repo](https://github.com/mariostoev/finviz).

### **Get-FVFilters**
This reaches out to the stock screener on [FinViz.com](https://finviz.com/) (using [`Invoke-WebRequest`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-webrequest)) and gathers every filter (P/E, Market Cap, Shares Outstanding, etc.) as well as all options for each filter (for instance, the "Exchange" filter has AMEX, NASDAQ, and NYSE options). It is recommended to use the `Filter` parameter to specify which filter(s) you want.
#### Example 1
    PS > Get-FVFilters -Filter Price,P/E
    Description Filter   Values
    ----------- ------   ------
    P/E         fa_pe    {@{Description=Low (<15); Value=low; Enable=False}...
    Price       sh_price {@{Description=Under $1; Value=u1; Enable=False},...
#### Example 2
    PS > Get-FVFilters -Filter Price,P/E | Select -Expand Values
    Description     Value       Enable
    -----------     -----       ------
    Low (<15)       low         False
    Profitable (>0) profitable  False
    High (>50)      high        False
    Under 5         u5          False
    ...
    
### **Set-FVFilters**
Using the filters from [`Get-FVFilters`](#get-fvfilters), this allows you to set which ones you want, eg: Forward P/E: Over 10, P/B: Under 2, etc. You can pipe the previous command to this one and then specify which filter you what to set and which value you want to set it to (if you only want one filter). There's also a `Hashtable` parameter where you can specify as many filters as you want, along with the values.
#### Example 1
    PS > $Filters | Set-FVFilters -Filter Beta -Value 'Under 0'
    Description Filter   Values
    ----------- ------   ------
    Beta        ta_beta  {@{Description=Under 0; Value=u0; Enable=True}, @{...
#### Example 2
    PS > $Hash = @{'Price' = 'Under $1' ; 'Change' = 'Up 1%' ; 'Payout Ratio' = 'Over 10%'}
    PS > Get-FVFilters -Filter Price,Change,'Payout Ratio' | Set-FVFilters -Hashtable $Hash
    Description  Filter         Values
    -----------  ------         ------
    Payout Ratio fa_payoutratio {@{Description=None (0%); Value=none...
    Change       ta_change      {@{Description=Up; Value=u; Enable=False...
    Price        sh_price       {@{Description=Under $1; Value=u1; Enable=True}...

### **Get-FVURLs**
This function has a `SingleQuery` switch parameter where, if selected, it'll generate a single URL with all the specified filters and values specified by [`Set-FVFilters`](#set-fvfilters). Otherwise, it'll print out a list of individual URLs for each filter specified. This URL can then be piped to [`Get-FVStocks`](#get-fvstocks).
#### Example 1
    PS > Get-FVFilters -Filter Price,P/E | Set-FVFilters -Filter Price -Value 'Under $50' | Get-FVURLs
    Filter Value     URL
    ------ -----     ---
    Price  Under $50 https://finviz.com/screener.ashx?v=111sh_price_u50&ft=4
#### Example 2
    PS > $Filters | Set-FVFilters -Hashtable $Hash | Get-FVURLs -SingleQuery
    SearchFilter                       URL
    ------------                       ---
    {@{Filter=Payout Ratio; Value=O... https://finviz.com/screener.ashx?v=111&f=fa_payoutratio_o10,ta_change_u1,sh_price_u1&ft=4
Each filter and value has a reference code (not sure what to call it), which is used in the URL syntax to specify the filters; you can also use those values instead of typing the friendly description if you'd like, eg: 'cap' instead of 'Market Cap.', or 'u1' instead of "Under $1".
### **Get-FVStocks**
This function will use the URL from [`Get-FVURLs`](#get-fvurls) (with all the specified filters) and will get a list of stocks that match that filter. This function has 2 main parameters: `FinVizFilter` & `URL`.

With `FinVizFilter`, you can provide a FinViz filter from [`Get-FVFilters`](#get-fvfilters) and it'll invoke [`Get-FVURLs`](#get-fvurls) to get the URL for you. Alternatively, the URL parameter will, naturally, take a URL and pull the info that way.

There's a third parameter `FormatCurrency`, which will format all currencies to be more human-readable (ie: $1,954,000,000 vice 1954000000). These, of course, will be output as [`String`](https://learn.microsoft.com/en-us/dotnet/api/system.string) values so you won't really be able to sort the data but it'll be easier to read.
#### Example 1
    PS > Get-FVStocks -FVFilter $FinVizFilter
    Ticker   : AAPL
    Company  : Apple Inc.
    Sector   : Technology
    Industry : Consumer Electronics
    ...
#### Example 2
    PS > $FinVizFilter | Get-FVURLs -SingleQuery | Get-FVStocks | select Ticker,Price,P/E
    Ticker  Price P/E
    ------  ----- ---
    AAPL   148.19 29.02
    AMGN   223.53 22.73
    AXP    159.75 18.57
    ...
### **Get-FVTickerData**
This will take either a ticker symbol (e.g.: GOOG) or a [direct URL to the FinViz page](https://finviz.com/quote.ashx?t=GOOG&ty=c&p=d&b=1) for a stock. Again, this can take pipeline input from the [`Get-FVStocks`](#get-fvstocks) function. It then pulls all the fundamentals, etc. from that page.

As of now, it doesn't get data other than what's in the main table (like insider trading, financial statement data, etc.). I may be able to add that later if there's a desire for it.
#### Example 1
    PS > Get-FVStocks -URL $URL | Get-FVTickerData
    EPS Q/Q %  : -31.1
    Perf YTD % : 5.06
    Book/sh    : 27.83
    52W High % : -1.44
    ...
## Conclusion
Putting all the functions together, we get:

    PS > Get-FVFilters -Filter Index | Set-FVFilters -Filter Index -Value DJIA | Get-FVURLs -SingleQuery | Get-FVStocks | select -First 1 | Get-FVTickerData | select Ticker,Company,P/E,Beta,Dividend | Format-Table

    Ticker Company        P/E Beta Dividend
    ------ -------        --- ---- --------
    WMT    Walmart Inc. 42.67 0.47      2.2
