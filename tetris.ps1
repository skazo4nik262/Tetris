. "$PSScriptRoot\tetris_functions.ps1"

$form.Add_Paint({
    param($sender, $e)
    $g = $e.Graphics

    $borderThickness = 2
    $borderPen = Get-DarkerPen "Gray" $borderThickness
    $g.DrawRectangle($borderPen, 19, 19, ($grid.GetLength(1) * $cellSize + $borderThickness), ($grid.GetLength(0) * $cellSize + $borderThickness))
    $borderPen.Dispose()

    for($row = 0; $row -lt $grid.GetLength(0); $row++)
    {
        for($col = 0; $col -lt $grid.GetLength(1); $col++)
        {
            if(-not [string]::IsNullOrEmpty(($grid[$row, $col])))
            {
                Draw-Tile $g $col $row $grid[$row, $col]
            }
        }
    }

    if (-not $isGameOver -and $null -ne $shape)
    {
        for ($i = 0; $i -lt 4; $i++)
        {
            $bx = $currentX + $shape.Coordinates[$i,0]
            $by = $currentY + $shape.Coordinates[$i,1]
            if($by -ge 0){ Draw-Tile $g $bx $by $shape.Color}
        }
    }

    $cyanBrush = Get-BrushFromColor "Cyan"
    $whiteBrush = Get-BrushFromColor "White"
    $grayBrush = Get-BrushFromColor "Gray"

    $g.DrawString("TETRIS", $hudFont, $cyanBrush, 295, 25)
    $g.DrawString("Счёт: $script:score", $hudFont, $whiteBrush, 295, 70)
    $g.DrawString("Следующая:", $subFont, $cyanBrush, 295, 130)

    if($null -ne $nextShape)
    {
        for($i = 0; $i -lt 4; $i++)
        {
            $nx = 11 + $nextShape.Coordinates[$i,0]
            $ny = 6 + $nextShape.Coordinates[$i,1]
            Draw-Tile $g $nx $ny $nextShape.Color
        }
    }

    $g.DrawString("Управление:", $subFont, $grayBrush, 295, 280)
    $g.DrawString("<- / -> : Сдвиг", $subFont, $grayBrush, 295, 310)
    $g.DrawString("   ^    : Поворот", $subFont, $grayBrush, 295, 340)
    $g.DrawString("   v    : Ускорить", $subFont, $grayBrush, 295, 370)

    if ($isGameOver)
    {
        $redBrush = Get-BrushFromColor "Crimson"
        $g.DrawString("GAME OVER!", $gameOverFont, $redBrush, 75, 290)
        $g.DrawString("Нажмите R для рестарта", $subFont, $whiteBrush, 25, 325)
        $redBrush.Dispose()
    }
    $cyanBrush.Dispose()
    $whiteBrush.Dispose()
    $grayBrush.Dispose()
})

$form.Add_KeyDown({
    param($sender, $e)

    if($isGameOver)
    {
        if($e.KeyCode -eq "R")
        {
            for ($r = 0; $r -lt $grid.GetLength(0); $r++) { for($c = 0; $c -lt $grid.GetLength(1);$c++) {$grid[$r, $c] = $null} }
            $script:score = 0
            $script:shapeDropTimer.Interval = $script:baseInterval
            $script:shape = Get-RandomShape
            $script:nextShape = Get-RandomShape
            $script:currentX = 4
            $script:currentY = 0
            $script:isGameOver = $false
            $script:shapeDropTimer.Start()
            $form.Invalidate()
        }
        return
    }

    switch ($e.KeyCode)
    {
        "Left" {$script:moveLeft = $true}
        "Right" {$script:moveRight = $true}
        "Down" {$script:shapeDropTimer.Interval = 50}
        "Up"
        {
            $rotated = Rotate-Shape $script:shape
            if (-not (Test-Collision $script:currentX $script:currentY $rotated))
            {
                $script:shape = $rotated
                $form.Invalidate()
            }
        }
    }
})

$form.Add_KeyUp({
    param($sender, $e)
    switch($e.KeyCode)
    {
        "Left" { $script:moveLeft = $false; $script:moveCooldown = 0}
        "Right" { $script:moveRight = $false; $script:moveCooldown = 0}
        "Down"
        {
            $speedBonus = [Math]::Floor($script:score / 300) * 10
            $newInterval = [Math]::Max(100, $script:baseInterval - $speedBonus)
            $script:shapeDropTimer.Interval = $newInterval
        }
    }
})

$timer.Add_Tick({
    if($isGameOver){return}

    if($script:moveCooldown -gt 0)
    {
        $script:moveCooldown -= $timer.Interval
        return
    }

    $script:blockDeltaX = 0
    if($script:moveLeft) {$script:blockDeltaX = -1}
    if($script:moveRight) {$script:blockDeltaX = 1}

    if($script:blockDeltaX -ne 0)
    {
        if(-not (Test-Collision ($script:currentX + $script:blockDeltaX) $script:currentY $script:shape))
        {
            $script:currentX += $script:blockDeltaX
            $script:moveCooldown = 90
            $form.Invalidate()
        }
    }
})

$shapeDropTimer.Add_Tick({
    if($isGameOver) {return}

    if (-not (Test-Collision $script:currentX ($script:currentY + 1) $script:shape))
    {
        $script:currentY++
    }
    else
    {
        for ($i =0; $i -lt 4; $i++)
        {
            $row = $script:currentY + $script:shape.Coordinates[$i, 1]
            $col = $script:currentX + $script:shape.Coordinates[$i, 0]
            if ($row -ge 0) {$grid[$row,$col] = $script:shape.Color}
        }

        Check-Lines

        $script:currentX = 4
        $script:currentY = 0
        $script:shape = $script:nextShape
        $script:nextShape = Get-RandomShape

        if (Test-Collision $script:currentX $script:currentY $script:shape)
        {
            $script:isGameOver = $true
            $script:shapeDropTimer.Stop()
        }
    }
    $form.Invalidate()
})

Window-Initialize
$shape = Get-RandomShape
$nextShape = Get-RandomShape
$timer.Start()
$shapeDropTimer.Start()
[System.Windows.Forms.Application]::Run($form)