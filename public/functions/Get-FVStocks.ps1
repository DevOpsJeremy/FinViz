function Get-FVStocks {
    [CmdletBinding(
        DefaultParameterSetName = 'URL',
        SupportsShouldProcess,
        ConfirmImpact = 'Medium'
    )]
    param (
        [Parameter(
            ParameterSetName = 'Filter'
        )]
        $FinVizFilter,
        [Parameter(
            ParameterSetName = 'URL',
            ValueFromPipelineByPropertyName = $true
        )]
        [string]$URL = "https://finviz.com/screener.ashx?v=111&ft=4",
        [Parameter(
            ParameterSetName = 'Filter'
        )]
        [Parameter(
            ParameterSetName = 'URL'
        )]
        [switch]$FormatCurrency
    )
    function ToNumber {
    param([string] $NumberString)
    $multipliers = @{
        'T' = 1000000000000
        'B' = 1000000000
        'M' = 1000000
        'K' = 1000
        '' = 1
    }
    switch -regex ($numberString)
    {
        '^(?<base>[\d\.]+)(?<suffix>\w*)$'
        {
            $base = [double] $matches['base']
            $multiplier = [int64] $multipliers[$matches['suffix']]

            if($multiplier)
            {
                [int64]($base * $multiplier)
            }
            else
            {
                throw "$($matches['suffix']) is an unknown suffix"
            }
        }
    }
    }
    function ToCurrency {
        param (
            [ValidateSet("USD","EUR","GBP")]$C = "USD",
            [int64]$Num,
            [switch]$Decimal
        )
        if ($Decimal){
            $N = 2
        } else {
            $N = 0
        }
        $Symbols = @{
            "USD" = "$"
            "EUR" = "€"
            "GBP" = "£"
        }
        $Sym = $Symbols[$C]
        $Price = $Sym + $("{0:N$N}" -f $Num)
        return $Price
    }
    if ($PSCmdlet.ParameterSetName -eq 'Filter'){
        $URL = Get-FVURLs -FinVizFilter $FinVizFilter -SingleQuery | Select-Object -ExpandProperty URL
    }
    $WR = Invoke-WebRequest -Uri $URL
    [int]$TotalResults = ($WR.ParsedHtml.Body.getElementsByClassName("count-text") | Where-Object InnerText -like Total* | Select-Object -ExpandProperty InnerText).Split() | Where-Object {$_ -notlike "Total*" -and $_ -notlike "#*"}
    [int]$TotalPages = if ($TotalResults -le 20){
        1
    } else {
        $WR.ParsedHtml.Body.getElementsByClassName("screener-pages") | Select-Object -ExpandProperty InnerText -Last 1
    }
    if ($TotalPages -gt 15){
        $ConfirmPreference = 'Medium'
    } else {
        $ConfirmPreference = 'High'
    }
    if ($PSCmdlet.ShouldProcess("$URL ($TotalPages pages)",$PSCmdlet.MyInvocation.InvocationName)){
        for ($Page = 0; $Page -lt $TotalPages; $Page++){
            $Count = 1 + $Page*20
            $PageURL = $URL + "&r=$Count"
            $PageWR = Invoke-WebRequest -Uri $PageURL
            $PageStocks = $PageWR.ParsedHtml.Body.getElementsByClassName("screener-link-primary")
            $PageStockData = $PageWR.ParsedHtml.Body.getElementsByClassName("screener-link") | ForEach-Object {
                $Property = @{
                    innerText = $_.innerText
                    search = $_.search
                }
                New-Object PSObject -Property $Property
            }
            $ParameterNames = $PageWR.ParsedHtml.Body.getElementsByClassName("table-top") | ForEach-Object {$_.innerText}
            foreach ($Stock in $PageStocks){
                $Ticker = $Stock.innerText
                $BaseSearch = $Stock.pathname
                $Search = $Stock.search
                $Data = $PageStockData | Where-Object search -eq $Search | ForEach-Object {$_.innerText}
                $Hash = [ordered]@{}
                $Hash.Ticker = $Ticker
                for ($PN = 1; $PN -lt $ParameterNames.Count; $PN++){
                    Remove-Variable Dat -Confirm:$false -ErrorAction SilentlyContinue
                    $Parameter = $ParameterNames[$PN]
                    if ($Data[$PN] -like "*%"){
                        $Parameter = $Parameter + ' %'
                    }
                    switch ($FormatCurrency){
                        $true {
                            switch ($Parameter) {
                                'Market Cap' {$Dat = ToCurrency -Num (ToNumber -NumberString $Data[$PN])}
                                'Price' {$Dat = ToCurrency -Num $Data[$PN] -Decimal}
                                'Volume' {[int64]$Dat = $Data[$PN]}
                                'Change %' {[float]$Dat = $Data[$PN].Trim('%')}
                                Default {$Dat = $Data[$PN]}
                            }
                        }
                        $false {
                            switch ($Parameter) {
                                'Market Cap' {[int64]$Dat = ToNumber -NumberString $Data[$PN]}
                                'Price' {[float]$Dat = $Data[$PN]}
                                'Volume' {[int64]$Dat = $Data[$PN]}
                                'Change %' {[float]$Dat = $Data[$PN].Trim('%')}
                                Default {$Dat = $Data[$PN]}
                            }
                        }
                    }
                    $Hash.$Parameter = $Dat
                }
                $Hash.URL = "https://finviz.com/" + $BaseSearch + $Search
                New-Object PSObject -Property $Hash
            }
        }
    }
}
