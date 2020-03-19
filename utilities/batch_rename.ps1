#([char[]]([char]33..[char]95) + ([char[]]([char]97..[char]126)) + 0..9 | sort {Get-Random})[0..8] -join ''
Foreach($srcFile in Get-ChildItem)
{
    $newName = ([char[]]([char]65..[char]90) + ([char[]]([char]97..[char]122)) | sort {Get-Random})[0..11] -join ''
    #$newNameFull = $newName + ".png"
    Copy-Item $srcFile $newName
}
