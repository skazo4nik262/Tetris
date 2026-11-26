Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$code = @"
using System.Windows.Forms;
public class GameForm : Form
{
    public GameForm()
    {
        this.DoubleBuffered = true;
    }
}

public class MyShape
{
    public int[,] Coordinates {get;set;}
    public string Color {get;set;}
}
"@

Add-Type -TypeDefinition $code -ReferencedAssemblies System.Windows.Forms

$form = New-Object GameForm

$colorNames = @("Crimson", "OrangeRed", "Gold", "LimeGreen", "DeepSkyBlue", "MediumOrchid", "Cyan")
[System.Collections.Generic.List[MyShape]]$shapesLibrary = [System.Collections.Generic.List[MyShape]]::new()

$hudFont = New-Object System.Drawing.Font("Consolas", 14, [System.Drawing.FontStyle]::Bold)
$gameOverFont = New-Object System.Drawing.Font("Consolas", 14, [System.Drawing.FontStyle]::Bold)
$subFont = New-Object System.Drawing.Font("Consolas", 14, [System.Drawing.FontStyle]::Regular)

$isGameOver = $false
$script:score = 0

$moveLeft = $false
$moveRight = $false
$dropDown = $false

$blockDeltaX = 0
$cellSize = 25
$currentX = 4
$currentY = 0
$moveCooldown = 0

$rawShapes  = @(
    @(@(0,0), @(1,0), @(0,1), @(1,1)),
    @(@(0,0), @(1,0), @(2,0), @(3,0)),
    @(@(1,0), @(0,1), @(1,1), @(2,1)),
    @(@(2,0), @(0,1), @(1,1), @(2,1)),
    @(@(0,0), @(0,1), @(1,1), @(2,1)),
    @(@(1,0), @(2,0), @(0,1), @(1,1)),
    @(@(0,0), @(1,0), @(1,1), @(2,1)) 
)
$grid = New-Object 'string[,]' 24,10

$script:timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 14

$script:baseInterval = 500

$script:shapeDropTimer = New-Object System.Windows.Forms.Timer
$shapeDropTimer.Interval = $script:baseInterval

for ($i =0; $i -lt $rawShapes.Count; $i++)
{
    $coords = New-Object 'int[,]' 4, 2
    for ($b = 0; $b -lt 4; $b++)
    {
        $coords[$b,0] = $rawShapes[$i][$b][0]
        $coords[$b,1] = $rawShapes[$i][$b][1]
    }
    $s = New-Object MyShape
    $s.Coordinates = $coords
    $s.Color = $colorNames[$i]
    $shapesLibrary.Add($s)
    
}

[MyShape]$shape = $null
[MyShape]$nextShape = $null

function Window-Initialize
{
    $form.Text = "Tetris"
    $form.ClientSize = New-Object System.Drawing.Size(500, 640)
    $form.FormBorderStyle = "FixedSingle"
    $form.MaximizeBox = $false
    $form.StartPosition = "CenterScreen"
    $form.BackColor = "Black"
}


function Get-DarkerPen([string]$colorString, [int]$thickness = 4)
{
    [System.Drawing.Color]$color = [System.Drawing.Color]::FromName($colorString)
    $r = [int]($color.R * 0.6)
    $g = [int]($color.G * 0.6)
    $b = [int]($color.B * 0.6)

    $darkColor = [System.Drawing.Color]::FromArgb($r,$g,$b)

    $pen = New-Object System.Drawing.Pen($darkColor, $thickness)
    $pen.Alignment = [System.Drawing.Drawing2D.PenAlignment]::Inset
    return $pen
}

function Get-BrushFromColor([string]$colorName)
{
    return New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromName($colorName))
}



function Draw-Tile($g, [int]$gridX, [int]$gridY, [string]$colorName)
{
    $px = 20 + ($gridX * $cellSize)
    $py = 20 + ($gridY * $cellSize)

    $brush = Get-BrushFromColor $colorName
    $pen = Get-DarkerPen $colorName 3

    $g.FillRectangle($brush, $px, $py, $cellSize, $cellSize)
    $g.DrawRectangle($pen, $px, $py, $cellSize, $cellSize)

    $brush.Dispose()
    $pen.Dispose()
}   



function Get-RandomShape
{
    $template = $shapesLibrary[(Get-Random -Minimum 0 -Maximum $shapesLibrary.Count)]

    $copy = New-Object MyShape
    $copy.Color = $template.Color
    $copy.Coordinates = $template.Coordinates.Clone()

    return $copy
}

function Rotate-Shape([MyShape]$currentShape)
{
    if ($currentShape.Color -eq "Crimson") {return $currentShape}
    $coords = $currentShape.Coordinates

    $minX = $coords[0,0]
    $maxX = $coords[0,0]
    $minY = $coords[0,1]
    $maxY = $coords[0,1]

    for($i = 1; $i -lt 4; $i++)
    {
        $x = $coords[$i,0]
        $y = $coords[$i,1]

        if ($x -lt $minX) { $minX = $x }
        if ($x -gt $maxX) { $maxX = $x }
        if ($y -lt $minY) { $minY = $y }
        if ($y -gt $maxY) { $maxY = $y }
    }

    $cx = [Math]::Round(($minX+$maxX) / 2)
    $cy = [Math]::Round(($minY+$maxY) / 2)

    $newCoords = New-Object 'int[,]' 4, 2

    for ($i = 0; $i -lt 4; $i++)
    {
        $relX = $coords[$i, 0] - $cx
        $relY = $coords[$i, 1] - $cy

        $newRelX = -$relY
        $newRelY = $relX

        $newCoords[$i,0] = [int]($newRelX + $cx)
        $newCoords[$i,1] = [int]($newRelY + $cy)
    }

    $rotated = New-Object MyShape
    $rotated.Color = $currentShape.Color
    $rotated.Coordinates = $newCoords
    return $rotated
}

function Check-Lines
{
    $linesClearedThisTurn = 0
    for ($row = ($grid.GetLength(0) - 1); $row -ge 0; $row--)
    {
        $isFull = $true
        for ($col = 0; $col -lt ($grid.GetLength(1)); $col++)
        {
            if ([string]::IsNullOrEmpty(($grid[$row, $col])))
            {
                $isFull = $false
                break
            }
        }

        if($isFull)
        {
            $linesClearedThisTurn++
            for ($moveRow = $row; $moveRow -gt 0; $moveRow--)
            {
                for($col = 0; $col -lt ($grid.GetLength(1)); $col++)
                {
                    $grid[$moveRow, $col] = $grid[($moveRow - 1), $col]
                }
            }
            for($col = 0; $col -lt ($grid.GetLength(1)); $col++)
            {
                $grid[0, $col] = $null
            }
            $row++
        }
    }

    if($linesClearedThisTurn -gt 0)
	{
		switch ($linesClearedThisTurn) 
		{
			1 { $script:score += 100 }
			2 { $script:score += 300 }
			3 { $script:score += 700 }
			4 { $script:score += 1500 }
		}
		
		$speedBonus = [Math]::Floor($script:score / 300) * 10
		$newInterval = $script:baseInterval - $speedBonus
		if ($newInterval -lt 100) { $newInterval = 100 }
		$script:shapeDropTimer.Interval = $newInterval
	}
}

function Test-Collision([int]$nextX, [int]$nextY, [MyShape]$checkShape)
{
    $coords = $checkShape.Coordinates
    for ($i = 0; $i -lt 4; $i++)
    {
        $targetX = $nextX + $coords[$i,0]
        $targetY = $nextY + $coords[$i,1]

        if ($targetX -lt 0 -or $targetX -ge 10 -or $targetY -ge 24) {return $true}

        if ($targetY -ge 0)
        {
            if(-not [string]::IsNullOrEmpty(($grid[$targetY, $targetX])))
            {
                return $true
            }
        }
    }
    return $false
}

