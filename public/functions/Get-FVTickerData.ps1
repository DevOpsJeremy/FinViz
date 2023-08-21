function Get-FVTickerData {
    [CmdletBinding(
        DefaultParameterSetName = 'Ticker'
    )]
    param (
        [Parameter(
            ParameterSetName = 'Ticker',
            Mandatory = $true
        )]
        [string]$Ticker,
        [Parameter(
            ParameterSetName = 'URL',
            ValueFromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [string]$URL
    )
    if ($PSCmdlet.ParameterSetName -eq 'Ticker'){
        $URL = "https://finviz.com/quote.ashx?t=" + $Ticker + "&ty=c&p=d&b=1"
    }
    $WR = Invoke-WebRequest -Uri $URL
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
    $Parsed = $WR.ParsedHtml
    $Title = $Parsed.Title
    $Ticker = $Title.Split()[0]
    $Company = $Title.Trim($Ticker).Trim("Stock Quote").Trim()
    $Table = $Parsed.getElementsByTagName("TABLE") | ForEach-Object {
        if ($_.classname -eq 'snapshot-table2'){$_}
    }
    $Titles = $Table.getElementsByClassName('snapshot-td2-cp') | ForEach-Object {$_.innerText}
    $Data = $Table.getElementsByClassName('snapshot-td2') | ForEach-Object {$_.innerText}
    $Hash = @{}
    $Hash.Ticker = $Ticker
    $Hash.Company = $Company
    $Hash.URL = $URL
    $Hash.CompanyURL = $Parsed.body.getElementsByClassName('tab-link') | ForEach-Object {
        if ($_.innerText -eq $Company){
            $_.href
        }
    }
    $BigNum = @(
        'Market Cap',
        'Income',
        'Sales',
        'Shs Outstand',
        'Shs Float',
        'Avg Volume'
    )
    for ($int = 0; $int -lt $Titles.Count; $int++){
        Remove-Variable D -Confirm:$false -ErrorAction SilentlyContinue
        $T = $Titles[$int]
        $D = $Data[$int]
        if ($D.Trim() -like '*%' -and $T -ne 'Volatility'){
            $T = $T + ' %'
            $D = $D.Trim('%')
        }
        if ($BigNum -contains $T){
            [int64]$D = ToNumber -NumberString $D
        } elseif ($T -eq '52W Range') {
            [float[]]$D = $D.Split('-').Trim()
        } elseif ($T -eq 'Volatility'){
            $Arr = $D.Split().Trim('%')
            $D = [ordered]@{}
            $Week = $Arr[0]
            $Month = $Arr[1]
            [float]$D.Week = $Week
            [float]$D.Month = $Month
            $T = $T + ' %'
        } elseif ($T -eq 'Volume') {
            [int64]$D = $D
        } else {
            try {
                [float]$D = $D
            }
            catch {
                $D = $D
            }
        }
        $Hash.$T = $D
    }
    New-Object PSObject -Property $Hash
}
