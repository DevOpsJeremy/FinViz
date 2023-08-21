function Set-FVFilters {
    [CmdletBinding(
        DefaultParameterSetName = 'Single'
    )]
    param (
        [Parameter(
            ValueFromPipeline = $true,
            ParameterSetName = 'Single',
            Mandatory = $true
        )]
        [Parameter(
            ValueFromPipeline = $true,
            ParameterSetName = 'Hash',
            Mandatory = $true
        )]
        $FinVizFilter,
        [Parameter(
            ParameterSetName = 'Single',
            Mandatory = $true
        )]
        $Filter,
        [Parameter(
            ParameterSetName = 'Single',
            Mandatory = $true
        )]
        $Value,
        [Parameter(
            ParameterSetName = 'Hash',
            Mandatory = $true
        )]
        [Hashtable]$Hashtable
    )
    Begin {
        function SetVal {
            param (
                $In,
                $Filt,
                $Val
            )
            $NewArr = @()
            foreach ($Item in $In){
                $D = $Item.Description
                $F = $Item.Filter
                if ($Filt -eq $D -or $Filt -eq $F){
                    $Vs = @()
                    foreach ($V in $Item.Values){
                        if ($V.Description -eq $Val -or $V.Value -eq $Val){
                            $Vs += [PSCustomObject]@{
                                Description = $V.Description
                                Value = $V.Value
                                Enable = $true
                            }
                        } else {
                            $Vs += $V
                        }
                    }
                } else {
                    $Vs = $Item.Values
                }
                [FVFilter]@{
                    Description = $D
                    Filter = $F
                    Values = $Vs
                }
            }
        }
    }
    Process {
        $NewFilter = $FinVizFilter
        switch ($PSCmdlet.ParameterSetName){
            'Single' {
                SetVal -In $FinVizFilter -Filt $Filter -Val $Value
            }
            'Hash' {
                foreach ($Key in $Hashtable.Keys){
                    $NewFilter = SetVal -In $NewFilter -Filt $Key -Val $Hashtable[$Key]
                }
                $NewFilter
            }
        }
    }
}
