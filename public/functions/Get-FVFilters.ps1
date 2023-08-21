function Get-FVFilters {
    param (
        [String[]]$Filter
    )
    if (!($Filter)){
        Write-Warning "Since a Filter has not been specified this cmdlet will process all FinViz filters, which may take a significant amount of time."
    }
    $BaseURL = "https://finviz.com/screener.ashx?v=111&ft=4"
    $ErrorActionPreference = "SilentlyContinue"
    $All = Invoke-WebRequest -Uri $BaseURL
    ${Filters-Cells} = @()
    foreach ($i in $All.ParsedHtml.body.getElementsByClassName("filters-cells")){
        ${Filters-Cells} += $i
    }
    $title = @()
    $text = @()
    foreach ($i in ${Filters-Cells}){
        if ($i.innerHTML -like "<SPAN*"){
            $title += $i
        } else {
            $innerText = $i.innerText
            if ($innerText -ne "" -and $innerText -ne " " -and $null -ne $innerText){
                $text += $i
            }
        }
    }
    $Options = $All.ParsedHtml.body.getElementsByClassName("screener-combo-text")
    Add-Type -TypeDefinition @"
    public struct FVFilter {
        public string Description;
        public string Filter;
        public object[] Values;
    }
"@ -ErrorAction SilentlyContinue
    function SortVals {
        param (
            $ti,
            $te,
            $int
        )
        $Percent = 100*($int/$title.Count)
        Write-Progress -Activity "Sorting Filters" -PercentComplete $Percent -Status $ti
        $Opt = $Options[$int]
        $Opt = $Opt | Where-Object {$_.text -notlike "*Elite only*" -and $_.text -ne "Any"}
        $FCount = $Opt.Count
        $FInt = 100/$FCount
        $Perc = 0
        $FilterVals = foreach ($i in $Opt){
            $ValDesc = $i.Text
            Write-Progress -id 1 -Activity "Sorting Values for $ti" -PercentComplete $Perc -CurrentOperation $ValDesc
            $ValVal = $i.value
            $prop = [ordered]@{
                Description = $ValDesc
                Value = $ValVal
                Enable = $false
            }
            New-Object PSObject -Property $prop
            $Perc += $FInt
        }
        [FVFilter]@{
            Description = $ti
            Filter = $te
            Values = $FilterVals
        }
    }
    for ($integer = 0 ; $integer -lt $title.Count ; $integer ++){
        $desc = $title[$integer].innerText
        $filt = ($text[$integer].innerHTML -split 'data-filter="')[1].Split('"')[0]
        if ($Filter){
            if ($Filter -contains $desc -or $Filter -contains $filt){
                SortVals -ti $desc -te $filt -int $integer
            }
        } else {
            SortVals -ti $desc -te $filt -int $integer
        }
    }
}
