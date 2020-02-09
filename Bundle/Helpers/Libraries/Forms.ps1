class PSIrivenForms{

    static OpenFile($InitialLocation){
        [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
        $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $OpenFileDialog.initialDirectory = $InitialLocation
        $OpenFileDialog.filter = "Text files (*.txt)|*.txt"
        $OpenFileDialog.ShowDialog() | Out-Null
        $OpenFileDialog.filename
        $OpenFileDialog.ShowHelp = $true
    }

} # CLASS CLASS