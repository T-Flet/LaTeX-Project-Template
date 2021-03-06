<#
.SYNOPSIS
    Produce and compile a .tex file highlighting the changes of a .tex project compared with a given stored version of it
.DESCRIPTION
    Given the stored (in $ProgressFolder) name of a past version, produce and compile each of the following:
        - a single-.tex-script version of the current state
        - a single-.tex-script version of the current state WITH the differences from the past version highlighted
    The enforced naming convention for .tex and .pdf files in $ProgressFolder is v\d+ for a raw version and v\d+to\d+ for comparisons.
    (A minor naming exception exists for ingesting old versions: v\d[A-Za-z]*, e.g. v3b, indicating minor versions. This only applies to inputs; output versions are always just integers).
    The script calls compile_expanded.ps1 to produce the first output; it automatically cleans up all intermediate files and opens the differences pdf.
    The aforementioned cleanup is indiscriminate, so DO NOT name files in the same folder $Old*, $New* or $Diff*.
.PARAMETER OldVersion
    The integer number representing the name of the stored old version to compare the current state with (or at most an integer followed by letters, indicating a minor version, e.g. 3b). Defaults to the latest integer version in the $ProgressFolder folder, making the output the next integer
.PARAMETER FileName
    The name (without extension) of the main .tex to compile. Defaults to Main
.PARAMETER ProgressFolder
    The name of the folder in which past versions (and their comparisons) are stored; created if not present
.PARAMETER New
    The TEMPORARY name (without extension) of the expanded .tex and .pdf of the current state version; the output placed in $ProgressFolder is renamed to v\d+, where the integer is one more than the old version. Defaults to NEW_EXPANDED
.PARAMETER Diff
    The TEMPORARY name (without extension) of the expanded .tex and .pdf of the differences between old and new versions; the output placed in $ProgressFolder is renamed to v${OldVersion}to\d+, where the integer is one more than the integer of the old version. Defaults to DIFF_EXPANDED
.PARAMETER ShowPdf
    Open the output (diff) pdf in the default pdf reader
.PARAMETER SuppressDiff
    Do not generate the diff .tex (nor .pdf), i.e. just save the current version's single-.tex-script and .pdf to the $ProgressFolder
.EXAMPLE
    Letting all arguments handle themselves is recommended:    
    PS> compile_diff.ps1
    Alternatively:
    PS> compile_diff.ps1 PastVersionToCompareWith MyTexName MyOldName MyTempNewName MyTempDiffName
#>
param(
    [parameter(Mandatory = $false)][string]$OldVersion,
    [string]$FileName = 'Main',
    [string]$ProgressFolder = 'Progress',
    [string]$New = 'NEW_EXPANDED',
    [string]$Diff = 'DIFF_EXPANDED',
    [switch]$ShowPdf = $false,
    [switch]$SuppressDiff = $false
)

function save_as_v1 {
    Write-Output "No past versions found; creating and saving current version as v1`n"
    latexpand "$FileName.tex" > "$New.tex"
    & .\compile.ps1 -FileName $New -Cleanup
    'tex', 'pdf' | ForEach-Object { Move-Item "$New.$_" -Destination "$ProgressFolder\v1.$_" }
}

function generate_compile_and_store {
    param (
        [string]$TempName, # Script-scope: either $New or $Diff
        [string]$FinalName, # Local-scope: either $NewName or $DiffName
        [string]$DiffFromName = $null, # Either null (for latexpand instead of latexdiff) or local-scope $Old
        [string]$DiffToName = $null # Either null (for latexpand instead of latexdiff) or local-scope "$ProgressFolder\$NewName"
    )
    Write-Output "`n`nThe temporary name $TempName will be used for the current document during compilation; renaming will occur when moving to the $ProgressFolder folder"

    if ($DiffFromName) {
        Write-Output "`nGenerating diff document $Diff.tex from $DiffFromName.tex`n"
        latexdiff -t CTRADITIONAL "$DiffFromName.tex" "$DiffToName.tex" > "$Diff.tex"
    } else {
        Write-Output "`nGenerating single-file $TempName.tex`n"
        latexpand "$FileName.tex" > "$TempName.tex"
    }

    Write-Output "Compiling and $TempName.tex to $FinalName.pdf`n`n"
    & .\compile.ps1 -FileName $TempName -Cleanup

    Write-Output "`n`nMoving $TempName .tex and .pdf files to $ProgressFolder folder, renamed to $FinalName"
    'tex', 'pdf' | ForEach-Object { Move-Item "$TempName.$_" -Destination "$ProgressFolder\$FinalName.$_" }
}


if (Test-Path $ProgressFolder -PathType Container) {
    $PastVersions = Get-ChildItem $ProgressFolder -Filter '*.tex' | Where-Object { $_.Name -match 'v\d+.tex' }

    if ($PastVersions.Count -eq 0) { save_as_v1 } else {
        $LatestVersion = ($PastVersions | Where-Object { $_.Name -match 'v(\d+).tex' } |
            ForEach-Object {[int]$Matches[1]} | Measure-Object -Maximum).Maximum
        
        if ($PSBoundParameters.ContainsKey('OldVersion')) {
            if ($OldVersion -match '(\d+)([A-Za-z]*)') { $OldInt = [int]$Matches[1] } else {
                Write-Output "Terminating script because inputed old version $OldVersion does not match the \d+[A-Za-z]* pattern"
                Break Script
            } 
        } else {
            Write-Output "Using latest version found: v$LatestVersion"
            $OldVersion = $LatestVersion
            $OldInt = [int]$OldVersion
        }

        $Old = "$ProgressFolder\v$OldVersion"
        $NewName = "v$($OldInt+1)"
        $DiffName = "v${OldVersion}to$($OldInt+1)"

        if (Test-Path "$Old.tex") {
            generate_compile_and_store $New $NewName
            if (!$SuppressDiff) { generate_compile_and_store $Diff $DiffName $Old "$ProgressFolder\$NewName" }
            if ($ShowPdf -and !$SuppressDiff) { Start-Process "$ProgressFolder\$DiffName.pdf" }
        } else { Write-Output "$Old.tex not found; try latest version (v$LatestVersion) instead" }
    }
} else {
    Write-Output "No $ProgressFolder folder present; creating it"
    New-Item $ProgressFolder -ItemType Directory
    save_as_v1
}


