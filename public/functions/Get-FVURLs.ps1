function Get-FVURLs {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        $FinVizFilter,
        [switch]$SingleQuery
    )
    Begin {
        $BaseURL = "https://finviz.com/screener.ashx?v=111"
        $FilterList = @()
        $SearchURL = ""
    }
    Process {
        switch ($SingleQuery){
            $true {
                foreach ($Filter in $FinVizFilter){
                    $Description = $Filter.Description
                    $BaseFilter = $Filter.Filter
                    $Values = $Filter.Values | Where-Object Enable -eq $true
                    if ($Values.Count -gt 0){
                        Write-Warning "Multiple values selected for $Description. Only the first value will be used."
                        $Values = $Values[0]
                    }
                    if ($Values.Count -ne 0){
                        $Val = $Values.Description
                        $SearchQuery = $BaseFilter,$Values.Value -join '_'
                        if ($SearchURL -ne ""){
                            $SearchURL += ','
                        }
                        $SearchURL += $SearchQuery
                        $FilterList += [PSCustomObject]@{
                            Filter = $Description
                            Value = $Val
                        }
                    }
                }
            }
            $false {
                foreach ($Filter in $FinVizFilter){
                    $Description = $Filter.Description
                    $BaseFilter = $Filter.Filter
                    $ModURL = $BaseURL + '&f=' + $BaseFilter + "_"
                    foreach ($Val in $Filter.Values){
                        if ($Val.Enable -eq $true){
                            $FinalURL = $ModURL + $Val.Value + "&ft=4"
                            [PSCustomObject]@{
                                Filter = $Description
                                Value = $Val.Description
                                URL = $FinalURL
                            }
                        }
                    }
                }
            }
        }
    }
    End {
        if ($SingleQuery){
            $URL = if ($FilterList.Count -gt 0){
                $BaseURL + '&f=' + $SearchURL + '&ft=4'
            } else {
                $BaseURL + '&ft=4'
            }
            [PSCustomObject]@{
                SearchFilter = $FilterList
                URL = $URL
            }
        }
    }
}
