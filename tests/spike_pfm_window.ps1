# THROWAWAY SPIKE (never merged): can two HTML design boards be drawn in real Windows PowerShell 5.1 WinForms?
# Draws "Your Work" (1280x720 and 1707x1440) and the Step 8 card (1280x720) with fake data only, renders each
# with Control.DrawToBitmap and prints one SPIKE line and the PNG as PNGB64 lines. No network, no modules.
# The file is pure ASCII on purpose: Windows PowerShell 5.1 reads a file without a BOM as ANSI.
param([string]$OutDir = '')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -ReferencedAssemblies 'System.Windows.Forms', 'System.Drawing' -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;
public class RBox : Control
{
    public int Radius;
    public Color Fill = Color.White;
    public Color Line = Color.Transparent;
    public int LineW;
    public Color TopColor = Color.Transparent;
    public int TopW;
    public bool CenterText = true;
    public int TextPad = 0;
    public RBox()
    {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
    }
    public static GraphicsPath Round(RectangleF r, float rad)
    {
        GraphicsPath p = new GraphicsPath();
        if (rad <= 0) { p.AddRectangle(r); return p; }
        float d = rad * 2;
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }
    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.Clear(BackColor);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        float h = LineW / 2f;
        RectangleF rc = new RectangleF(h, h, Width - LineW, Height - LineW);
        if (LineW == 0) rc = new RectangleF(0, 0, Width, Height);
        using (GraphicsPath p = Round(rc, Radius))
        {
            using (SolidBrush b = new SolidBrush(Fill)) g.FillPath(b, p);
            if (TopW > 0)
            {
                g.SetClip(p);
                using (SolidBrush b = new SolidBrush(TopColor)) g.FillRectangle(b, 0, 0, Width, TopW);
                g.ResetClip();
            }
            if (LineW > 0)
            {
                using (Pen pen = new Pen(Line, LineW)) g.DrawPath(pen, p);
            }
        }
        if (!String.IsNullOrEmpty(Text))
        {
            TextFormatFlags f = TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.NoPadding | TextFormatFlags.NoPrefix;
            Rectangle tr = new Rectangle(TextPad, 0, Width - TextPad, Height);
            if (CenterText) { f |= TextFormatFlags.HorizontalCenter; tr = ClientRectangle; } else f |= TextFormatFlags.Left;
            TextRenderer.DrawText(g, Text, Font, tr, ForeColor, f);
        }
    }
}
'@

function C([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
$mid = [string][char]0x00B7
$gt = [string][char]0x203A
$tick = [string][char]0x2713
$PAGE = C '#EEF1F5'; $NAVY = C '#0B2545'; $INK = C '#1B1F2A'; $MUTED = C '#5B6B7F'; $BLUE = C '#00539F'
$LINE = C '#C9D2DC'; $WHITE = C '#FFFFFF'; $NAVTXT = C '#DDE8F3'
$CHIP = @{
    turn = @((C '#FFD520'), $INK); late = @((C '#F6D5DA'), $INK); soon = @((C '#F8E8C4'), $INK)
    ok = @((C '#D6EBDD'), $INK); neu = @((C '#EEF1F5'), $INK)
}
$FONTS = @{}
function Fnt([double]$px, [bool]$bold, [string]$face = 'Segoe UI') {
    $k = "$face|$px|$bold"
    if (-not $FONTS.ContainsKey($k)) {
        $st = [System.Drawing.FontStyle]::Regular
        if ($bold) { $st = [System.Drawing.FontStyle]::Bold }
        $FONTS[$k] = New-Object System.Drawing.Font($face, [single]$px, $st, [System.Drawing.GraphicsUnit]::Pixel)
    }
    $FONTS[$k]
}
function TextW([string]$t, $font) {
    [System.Windows.Forms.TextRenderer]::MeasureText($t, $font, (New-Object System.Drawing.Size(100000, 0)), [System.Windows.Forms.TextFormatFlags]'NoPadding, NoPrefix').Width
}
function TextH([string]$t, $font, [int]$w) {
    [System.Windows.Forms.TextRenderer]::MeasureText($t, $font, (New-Object System.Drawing.Size($w, 0)), [System.Windows.Forms.TextFormatFlags]'WordBreak, NoPadding, NoPrefix').Height
}

function New-Box($parent, [string]$name, [int]$x, [int]$y, [int]$w, [int]$h, $fill, [int]$radius, $line, [int]$lineW) {
    $b = New-Object RBox
    $b.AccessibleName = $name
    $b.TabStop = $false
    $b.BackColor = $parent.BackColor
    $b.Fill = $fill; $b.Radius = $radius; $b.LineW = $lineW
    if ($null -ne $line) { $b.Line = $line }
    $b.SetBounds($x, $y, $w, $h)
    $parent.Controls.Add($b)
    $b
}
function New-Chip($parent, [string]$kind, [string]$text, [int]$x, [int]$y, [int]$w, [int]$h, [double]$px) {
    $b = New-Box $parent $text $x $y $w $h $CHIP[$kind][0] ([int]($h / 2)) $null 0
    $b.Text = $text; $b.Font = Fnt $px $true; $b.ForeColor = $CHIP[$kind][1]
    $b
}
function New-Lbl($parent, [string]$text, [int]$x, [int]$y, [int]$w, [int]$h, [double]$px, [bool]$bold, $fore, [string]$align = 'L', [bool]$wrap = $false, [string]$face = 'Segoe UI') {
    $l = New-Object System.Windows.Forms.Label
    $l.AutoSize = $false
    $l.UseMnemonic = $false
    $l.Text = $text
    $l.AccessibleName = $text
    $l.Font = Fnt $px $bold $face
    $l.ForeColor = $fore
    $l.BackColor = [System.Drawing.Color]::Transparent
    $l.Padding = New-Object System.Windows.Forms.Padding(0)
    $l.Margin = New-Object System.Windows.Forms.Padding(0)
    if ($align -eq 'R') { $l.TextAlign = 'TopRight' } elseif ($align -eq 'C') { $l.TextAlign = 'TopCenter' } else { $l.TextAlign = 'TopLeft' }
    if ($wrap) { $l.Tag = 'wrap' }
    $l.SetBounds($x, $y, $w, $h)
    $parent.Controls.Add($l)
    $l
}
# text label whose height is measured
function New-Para($parent, [string]$text, [int]$x, [int]$y, [int]$w, [double]$px, [bool]$bold, $fore) {
    $h = TextH $text (Fnt $px $bold) $w
    New-Lbl $parent $text $x $y $w ($h + 1) $px $bold $fore 'L' $true
}
function New-Btn($parent, [string]$text, [int]$x, [int]$y, [int]$w, [int]$h, [bool]$primary, [double]$px) {
    $b = New-Object System.Windows.Forms.Button
    $b.AccessibleName = $text
    $b.Text = $text
    $b.UseMnemonic = $false
    $b.FlatStyle = 'Flat'
    $b.UseVisualStyleBackColor = $false
    $b.Cursor = 'Hand'
    $b.Padding = New-Object System.Windows.Forms.Padding(0)
    if ($primary) {
        $b.BackColor = $BLUE; $b.ForeColor = $WHITE; $b.FlatAppearance.BorderSize = 0
        $b.Font = Fnt $px $true
    } else {
        $b.BackColor = $WHITE; $b.ForeColor = $INK
        $b.FlatAppearance.BorderSize = 1; $b.FlatAppearance.BorderColor = $MUTED
        $b.Font = Fnt $px $false 'Segoe UI Semibold'
    }
    $b.SetBounds($x, $y, $w, $h)
    $parent.Controls.Add($b)
    $b
}
function BtnW([string]$text, [double]$px, [bool]$bold, [int]$pad) {
    $f = Fnt $px $bold
    if (-not $bold) { $f = Fnt $px $false 'Segoe UI Semibold' }
    (TextW $text $f) + 2 * $pad
}
function New-Hr($parent, [int]$x, [int]$y, [int]$w, $color) {
    $b = New-Box $parent 'separator line' $x $y $w 1 $color 0 $null 0
    $b
}

function Build-Nav($root, [int]$navW, [int]$H) {
    $nav = New-Object System.Windows.Forms.Panel
    $nav.AccessibleName = 'Main menu'
    $nav.BackColor = $NAVY
    $nav.SetBounds(0, 0, $navW, $H)
    $root.Controls.Add($nav)
    # the logo image is not part of the spike: a plain outlined square stands in
    $logo = New-Box $nav 'logo placeholder' 18 18 40 40 $NAVY 8 $WHITE 2
    $tw = $navW - 24 - 6 - 40 - 10 - 6
    $null = New-Lbl $nav '90-161.Z' 68 18 $tw 24 18 $true $WHITE
    $sub = 'Publications and Forms'
    $sh = TextH $sub (Fnt 12 $false) $tw
    $null = New-Lbl $nav $sub 68 42 $tw ($sh + 1) 12 $false $NAVTXT 'L' $true
    $items = @('Your Work', 'All Actions', 'Reviews Due', 'Publications', 'Settings')
    $y = 18 + 55 + 18
    if ($navW -gt 210) { $y = 18 + 40 + 22 }
    $i = 0
    foreach ($t in $items) {
        $on = ($i -eq 0)
        $fill = $NAVY; $fore = $NAVTXT
        if ($on) { $fill = $WHITE; $fore = $NAVY }
        $it = New-Box $nav $t 12 $y ($navW - 24) 44 $fill 4 $null 0
        $it.Text = $t; $it.CenterText = $false; $it.TextPad = 14; $it.ForeColor = $fore
        $it.Font = Fnt 15 $on
        $it.AccessibleRole = 'PushButton'
        if ($on) {
            $bd = New-Box $it '3 items need you' ($navW - 24 - 14 - 24) 12 24 20 (C '#FFD520') 10 $null 0
            $bd.Text = '3'; $bd.Font = Fnt 12 $true; $bd.ForeColor = $INK
        }
        $y += 48
        $i++
    }
    $null = New-Lbl $nav ('Sample data ' + $mid + ' preview 1' + [Environment]::NewLine + 'Version 0.2') 14 ($H - 18 - 36) ($navW - 28) 36 12 $false $NAVTXT
    $nav
}

$ROWS = @(
    'Sample OI 33-101|Key Control|Review|8 PFM check|You|16 Nov|1 d|18 Nov|turn|Your turn',
    'Sample OI 21-14|Vehicle Keys|Review|11 Signatures|You|13 Nov|2 d|20 Nov|turn|Your turn',
    'Sample Instruction 10-201|Recall|Rewrite|10 Wave 1|Sample Office 5|23 Oct|17 d|13 Nov|late|Late',
    'Sample OI 31-3|Gate Hours|Review|10 Wave 2|Sample Office 8|26 Oct|16 d|16 Nov|late|Late',
    'Sample OI 90-1|Self-Inspection|Review|10 Wave 3, legal|Sample Legal Office|29 Oct|13 d|19 Nov|soon|Due soon',
    'Sample OI 36-2|Recognition|Change|10 Wave 1|2 offices|30 Oct|12 d|20 Nov|soon|Due soon',
    'Sample OI 10-5|Recall Roster|Certify current|11 Signatures|Wing Staff CSS|12 Nov|3 d|19 Nov|ok|On track',
    'Sample OI 13-4|Airfield Signs|Review|3 AOs named|Sample Office 3 box|12 Nov|3 d|26 Nov|ok|On track',
    'Sample OI 48-2|Hearing Tests|Review|9 Answers|Sample AO 6|11 Nov|4 d|25 Nov|ok|On track',
    'Sample OI 32-1|Work Orders|Review|5 Scope|Sample AO 5|10 Nov|5 d|24 Nov|ok|On track',
    'Sample OI 91-3|Ladder Safety|New|7 Endorsers|Sample AO 7|9 Nov|6 d|1 Dec|ok|On track',
    'Sample Form 12|Key Log|Form|6 Draft|Sample AO 1|5 Nov|8 d|3 Dec|ok|On track',
    'Sample OI 21-6|Tool Control|Review|6 Draft|Sample AO 4|2 Nov|11 d|4 Dec|ok|On track',
    'Sample OI 23-7|Supply Bins|Rewrite|6 Draft|Sample AO 8|28 Oct|14 d|18 Dec|ok|On track',
    'Sample OI 15-1|Weather Calls|Review|2 Box told|Sample Office 9 box|16 Nov|1 d|30 Nov|ok|On track'
)

# the board: a DataGridView (see the report for why); the Publication, With and Status cells are painted by hand
function New-Board($parent, [int]$x, [int]$y, [int]$w, [int]$h, [bool]$wide) {
    $g = New-Object System.Windows.Forms.DataGridView
    $g.AccessibleName = 'Who has it now board'
    $g.SetBounds($x, $y, $w, $h)
    $g.AllowUserToAddRows = $false; $g.AllowUserToDeleteRows = $false
    $g.AllowUserToResizeRows = $false; $g.AllowUserToResizeColumns = $false
    $g.ReadOnly = $true; $g.RowHeadersVisible = $false; $g.MultiSelect = $false
    $g.SelectionMode = 'FullRowSelect'
    $g.EnableHeadersVisualStyles = $false
    $g.ColumnHeadersHeightSizeMode = 'DisableResizing'
    $g.ColumnHeadersHeight = 33
    $g.RowTemplate.Height = 41
    $g.CellBorderStyle = 'None'
    $g.ColumnHeadersBorderStyle = 'None'
    $g.BorderStyle = 'None'
    $g.BackgroundColor = $WHITE
    $g.GridColor = $LINE
    $g.AutoSizeColumnsMode = 'None'
    $g.ScrollBars = 'Vertical'
    $g.DefaultCellStyle.Font = Fnt 14 $false
    $g.DefaultCellStyle.ForeColor = $INK
    $g.DefaultCellStyle.BackColor = $WHITE
    $g.DefaultCellStyle.SelectionBackColor = $PAGE
    $g.DefaultCellStyle.SelectionForeColor = $INK
    $g.ColumnHeadersDefaultCellStyle.BackColor = $WHITE
    $g.ColumnHeadersDefaultCellStyle.ForeColor = $MUTED
    $g.ColumnHeadersDefaultCellStyle.Font = Fnt 12 $true
    $g.ColumnHeadersDefaultCellStyle.SelectionBackColor = $WHITE
    if ($wide) {
        $defs = @(@('Publication', 0), @('Action', 136), @('Step', 136), @('With', 184), @('Since', 120), @('Due', 72), @('Status', 104))
    } else {
        $defs = @(@('Publication', 0), @('Step', 128), @('With', 170), @('Since', 64), @('Due', 72), @('Status', 104))
    }
    $fixed = 0
    foreach ($d in $defs) { $fixed += $d[1] }
    $scroll = 0
    if (($ROWS.Count * 41 + 33) -gt $h) { $scroll = 17 }
    foreach ($d in $defs) {
        $c = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $c.Name = $d[0]; $c.HeaderText = $d[0]
        $c.SortMode = 'NotSortable'
        $c.Width = $d[1]
        if ($d[1] -eq 0) { $c.Width = $w - $fixed - $scroll }
        $g.Columns.Add($c) | Out-Null
    }
    foreach ($r in $ROWS) {
        $f = $r.Split('|')
        $pub = $f[0] + '|' + $f[1]
        if ($wide) {
            $vals = @($pub, $f[2], $f[3], $f[4], ($f[5] + ' ' + $mid + ' ' + $f[6]), $f[7], $f[9])
        } else {
            $vals = @($pub, $f[3], $f[4], $f[6], $f[7], $f[9])
        }
        $g.Rows.Add([object[]]$vals) | Out-Null
    }
    $kindOf = @{}
    foreach ($r in $ROWS) { $f = $r.Split('|'); $kindOf[$f[9]] = $f[8] }
    $script:gridKinds = $kindOf
    $g.add_CellPainting({
        param($s, $e)
        $name = $s.Columns[$e.ColumnIndex].Name
        $b = $e.CellBounds
        $gr = $e.Graphics
        $fl = [System.Windows.Forms.TextFormatFlags]'Left, VerticalCenter, SingleLine, NoPadding, NoPrefix, EndEllipsis'
        $tr = New-Object System.Drawing.Rectangle(($b.X + 10), $b.Y, ($b.Width - 20), ($b.Height - 1))
        if ($e.RowIndex -lt 0) {
            $gr.FillRectangle((New-Object System.Drawing.SolidBrush($WHITE)), $b)
            [System.Windows.Forms.TextRenderer]::DrawText($gr, ([string]$e.Value).ToUpper(), (Fnt 12 $true), $tr, $MUTED, $fl)
            $gr.DrawLine((New-Object System.Drawing.Pen($MUTED, 1)), $b.X, ($b.Bottom - 1), $b.Right, ($b.Bottom - 1))
            $e.Handled = $true
            return
        }
        $sel = $s.Rows[$e.RowIndex].Selected
        $bg = $WHITE
        if ($sel) { $bg = $PAGE }
        $gr.FillRectangle((New-Object System.Drawing.SolidBrush($bg)), $b)
        $gr.DrawLine((New-Object System.Drawing.Pen($LINE, 1)), $b.X, ($b.Bottom - 1), $b.Right, ($b.Bottom - 1))
        $text = [string]$e.Value
        if ($name -eq 'Publication') {
            $p = $text.Split('|')
            $lf = Fnt 14 $false
            $ul = New-Object System.Drawing.Font($lf, [System.Drawing.FontStyle]::Underline)
            $w1 = [System.Windows.Forms.TextRenderer]::MeasureText($p[0], $ul, (New-Object System.Drawing.Size(100000, 0)), [System.Windows.Forms.TextFormatFlags]'NoPadding, NoPrefix').Width
            [System.Windows.Forms.TextRenderer]::DrawText($gr, $p[0], $ul, $tr, $BLUE, $fl)
            $rest = New-Object System.Drawing.Rectangle(($tr.X + $w1 + 5), $tr.Y, ($tr.Width - $w1 - 5), $tr.Height)
            if ($rest.Width -gt 4) { [System.Windows.Forms.TextRenderer]::DrawText($gr, $p[1], $lf, $rest, $MUTED, $fl) }
            $ul.Dispose()
        } elseif ($name -eq 'With') {
            [System.Windows.Forms.TextRenderer]::DrawText($gr, $text, (Fnt 14 $true), $tr, $NAVY, $fl)
        } elseif ($name -eq 'Status') {
            $k = $script:gridKinds[$text]
            $cw = (TextW $text (Fnt 13 $true)) + 20
            $cy = $b.Y + [int](($b.Height - 1 - 26) / 2)
            $rc = New-Object System.Drawing.RectangleF(($b.X + 10), $cy, $cw, 26)
            $gr.SmoothingMode = 'AntiAlias'
            $path = [RBox]::Round($rc, 13)
            $gr.FillPath((New-Object System.Drawing.SolidBrush($CHIP[$k][0])), $path)
            $path.Dispose()
            $gr.SmoothingMode = 'Default'
            $cr = New-Object System.Drawing.Rectangle(($b.X + 10), $cy, [int]$cw, 26)
            [System.Windows.Forms.TextRenderer]::DrawText($gr, $text, (Fnt 13 $true), $cr, $CHIP[$k][1], [System.Windows.Forms.TextFormatFlags]'HorizontalCenter, VerticalCenter, SingleLine, NoPadding, NoPrefix')
        } else {
            [System.Windows.Forms.TextRenderer]::DrawText($gr, $text, (Fnt 14 $false), $tr, $INK, $fl)
        }
        $e.Handled = $true
    })
    $parent.Controls.Add($g)
    $g
}

# one ".co" row of the side panels: label left, a chip or a text right
function New-CoRow($parent, [int]$x, [int]$y, [int]$w, [string]$label, [string]$right, [string]$chip, [bool]$border) {
    $hh = 36
    if ($chip) { $hh = 43 }
    $null = New-Lbl $parent $label $x ($y + 8) ($w - 120) 19 14 $false $INK
    if ($chip) {
        $cw = (TextW $right (Fnt 13 $true)) + 20
        $null = New-Chip $parent $chip $right ($x + $w - $cw) ($y + 8) $cw 26 13
    } else {
        $null = New-Lbl $parent $right ($x + $w - 200) ($y + 8) 200 19 14 $false $INK 'R'
    }
    if ($border) { $null = New-Hr $parent $x ($y + $hh - 1) $w $LINE }
    $hh
}

function Build-Home($root, [int]$W, [int]$H) {
    $wide = ($W -gt 1500)
    $navW = 200; $rw = 300
    if ($wide) { $navW = 220; $rw = 420 }
    $null = Build-Nav $root $navW $H
    $lx = $navW + 28
    $lw = $W - $navW - 56 - 18 - $rw
    $null = New-Lbl $root 'Your Work' $lx 22 130 34 28 $true $NAVY
    $sub = 'Tuesday, 17 Nov 26 ' + $mid + ' 2 items need you ' + $mid + ' 2 offices late'
    $null = New-Lbl $root $sub ($lx + 138) 34 500 19 14 $false $MUTED

    # Needs You Today
    $nh = 222
    $card = New-Box $root 'Needs you today' $lx 70 $lw $nh $WHITE 6 $LINE 1
    $card.TopColor = $BLUE; $card.TopW = 4
    $null = New-Lbl $card 'NEEDS YOU TODAY' 18 18 300 16 12 $true $MUTED
    $need = @(
        @('turn', 'Due 18 Nov 26', 'Review and start endorsement', ('Sample OI 33-101, Key Control ' + $mid + ' step 8 of 12'), 'Open', $true),
        @('turn', 'Due 20 Nov 26', 'Build the final copy, then send for signatures', ('Sample OI 21-14, Vehicle Keys ' + $mid + ' step 11 of 12'), 'Open', $true),
        @('late', '2 late', 'Chase 2 late offices', ('Wave answers past due ' + $mid + ' last contact shown on the right'), 'Remind All Late', $false)
    )
    $y = 44
    foreach ($n in $need) {
        $null = New-Hr $card 1 $y ($lw - 2) $LINE
        $null = New-Chip $card $n[0] $n[1] 18 ($y + 17) 110 26 13
        $null = New-Lbl $card $n[2] 142 ($y + 9) ($lw - 142 - 140) 20 15 $true $INK
        $null = New-Lbl $card $n[3] 142 ($y + 30) ($lw - 142 - 140) 17 13 $false $MUTED
        $bw = BtnW $n[4] 14 $n[5] 14
        $null = New-Btn $card $n[4] ($lw - 18 - $bw) ($y + 12) $bw 36 $n[5] 14
        $y += 59
    }

    # Who Has It Now
    $wy = 70 + $nh + 14
    $wh = $H - 22 - $wy
    $who = New-Box $root 'Who has it now' $lx $wy $lw $wh $WHITE 6 $LINE 1
    $null = New-Lbl $who ('WHO HAS IT NOW ' + $mid + ' 15 OPEN ACTIONS') 14 10 400 16 12 $true $MUTED
    $note = 'Since: when it reached that person ' + $mid + ' d: business days ' + $mid + ' dates in 2026'
    $gy = 61
    if ($wide) {
        $null = New-Lbl $who $note ($lw - 14 - 500) 11 500 17 13 $false $MUTED 'R'
        $gy = 37
    } else {
        $null = New-Lbl $who $note ($lw - 14 - 500) 35 500 17 13 $false $MUTED 'R'
    }
    $grid = New-Board $who 1 $gy ($lw - 2) ($wh - $gy - 1) $wide

    # Chase
    $cx = $lx + $lw + 18
    $ch = New-Box $root 'Chase offices' $cx 70 $rw 100 $WHITE 6 $LINE 1
    $null = New-Lbl $ch ('CHASE ' + $mid + ' LATE AND DUE SOON') 16 12 ($rw - 32) 16 12 $true $MUTED
    $nt = 'Each reminder is logged as a contact: the good-faith record (DAFMAN 90-161, 5.4.3.1).'
    $np = New-Para $ch $nt 16 32 ($rw - 32) 13 $false $MUTED
    $y = 32 + $np.Height + 6
    $offices = @(
        @('Sample Office 5', ('Sample Instruction 10-201 ' + $mid + ' Wave 1'), ('Due 13 Nov 26 (2 d late) ' + $mid + ' last contact: 14 Nov 26 ' + $mid + ' contacts: 1'), $true),
        @('Sample Office 8', ('Sample OI 31-3 ' + $mid + ' Wave 2'), ('Due 16 Nov 26 (1 d late) ' + $mid + ' last contact: never ' + $mid + ' contacts: 0'), $true),
        @('Sample Legal Office', ('Sample OI 90-1 ' + $mid + ' Wave 3, legal ' + $mid + ' cannot be "Concur, No Response"'), ('Due 19 Nov 26 (due in 2 d) ' + $mid + ' last contact: never ' + $mid + ' contacts: 0'), $false),
        @('Sample Offices 2 and 4', ('Sample OI 36-2 ' + $mid + ' Wave 1'), ('Due 20 Nov 26 (due in 3 d) ' + $mid + ' last contact: never ' + $mid + ' contacts: 0'), $false)
    )
    $bw = (BtnW 'Remind' 14 $true 14)
    $tw = $rw - 32 - $bw - 10
    foreach ($o in $offices) {
        $null = New-Hr $ch 16 $y ($rw - 32) $LINE
        $yy = $y + 10
        $null = New-Lbl $ch $o[0] 16 $yy $tw 19 14 $true $INK
        $yy += 21
        $p1 = New-Para $ch $o[1] 16 $yy $tw 13 $false $MUTED
        $yy += $p1.Height + 2
        $p2 = New-Para $ch $o[2] 16 $yy $tw 13 $false $MUTED
        $yy += $p2.Height + 10
        $null = New-Btn $ch 'Remind' ($rw - 16 - $bw) ($y + [int](($yy - $y - 36) / 2)) $bw 36 $o[3] 14
        $y = $yy
    }
    $ch.Height = $y + 12

    if ($wide) {
        $sy = 70 + $ch.Height + 14
        $sel = New-Box $root 'Selected action' $cx $sy $rw 274 $WHITE 6 $LINE 1
        $null = New-Lbl $sel ('SELECTED ' + $mid + ' SAMPLE INSTRUCTION 10-201') 16 14 ($rw - 32) 16 12 $true $MUTED
        $iw = $rw - 32
        $yy = 38
        $yy += (New-CoRow $sel 16 $yy $iw 'Wave 1 (3 offices)' '2 of 3 answered' 'soon' $true) + 6
        $yy += (New-CoRow $sel 16 $yy $iw 'Wave 2 (5 mandatory)' 'Waiting' 'neu' $true) + 6
        $yy += (New-CoRow $sel 16 $yy $iw 'Wave 3, legal' 'Waiting' 'neu' $true) + 6
        $yy += (New-CoRow $sel 16 $yy $iw 'Contacts with Sample Office 5' ('1 ' + $mid + ' 14 Nov 26 0900') '' $false) + 6
        $b1 = BtnW 'Open the Action' 14 $false 14
        $b2 = BtnW 'Change or Skip' 14 $false 14
        $null = New-Btn $sel 'Open the Action' 16 $yy $b1 36 $false 14
        $null = New-Btn $sel 'Change or Skip' (16 + $b1 + 8) $yy $b2 36 $false 14
    }
    $grid
}

function Build-Step8($root, [int]$W, [int]$H) {
    $navW = 200
    $null = Build-Nav $root $navW $H
    $lx = $navW + 28
    $aw = 360
    $lw = $W - $navW - 56 - 22 - $aw
    # breadcrumb
    $bc = New-Object System.Windows.Forms.LinkLabel
    $bc.AutoSize = $false
    $bc.UseMnemonic = $false
    $bc.Text = 'Your Work ' + $gt + ' Sample OI 33-101'
    $bc.AccessibleName = 'Breadcrumb: Your Work, Sample OI 33-101'
    $bc.Font = Fnt 13 $false
    $bc.ForeColor = $MUTED; $bc.LinkColor = $BLUE; $bc.ActiveLinkColor = $NAVY
    $bc.BackColor = [System.Drawing.Color]::Transparent
    $bc.Padding = New-Object System.Windows.Forms.Padding(0)
    $bc.LinkArea = New-Object System.Windows.Forms.LinkArea(0, 9)
    $bc.SetBounds($lx, 22, 400, 17)
    $root.Controls.Add($bc)

    $card = New-Box $root 'Step 8 card' $lx 60 $lw 300 $WHITE 6 $LINE 1
    $iw = $lw - 48
    $x0 = 24
    $y = 22
    $null = New-Chip $card 'turn' 'YOUR TURN' $x0 $y 97 26 13
    $null = New-Chip $card 'soon' 'Due 18 Nov 26' ($x0 + 105) $y 110 26 13
    $null = New-Lbl $card ('STEP 8 OF 12 ' + $mid + ' PFM AND PRIVACY MONITOR') ($x0 + 105 + 110 + 8) ($y + 4) ($iw - 223) 16 12 $true $MUTED
    $y += 26 + 12
    $head = 'Is the draft of Sample OI 33-101 ready for endorsement?'
    $hp = New-Para $card $head $x0 $y $iw 26 $true $NAVY
    $y += $hp.Height + 14
    # the 12-dot step bar
    $steps = @('Review due', 'Box told', 'AOs named', 'AOs told', 'Scope', 'Draft', 'Endorsers', 'PFM check', 'Answers', 'Waves', 'Signatures', 'Posted')
    $cw = $iw / 12.0
    for ($i = 1; $i -lt 12; $i++) {
        $x1 = $x0 + ($i - 0.5) * $cw
        $col = C '#8FA3B8'
        if ($i -le 7) { $col = $BLUE }
        $null = New-Box $card ('connector to step ' + ($i + 1)) ([int]$x1) ($y + 12) ([int]$cw + 1) 3 $col 0 $null 0
    }
    for ($i = 0; $i -lt 12; $i++) {
        $cx = [int]($x0 + ($i + 0.5) * $cw - 13)
        $n = $i + 1
        if ($n -lt 8) { $d = New-Box $card ('step ' + $n + ' done: ' + $steps[$i]) $cx $y 26 26 $BLUE 13 $BLUE 2; $d.ForeColor = $WHITE; $lf = $INK; $lb = $false }
        elseif ($n -eq 8) { $d = New-Box $card ('step ' + $n + ' current: ' + $steps[$i]) $cx $y 26 26 (C '#FFD520') 13 $NAVY 3; $d.ForeColor = $INK; $lf = $NAVY; $lb = $true }
        else { $d = New-Box $card ('step ' + $n + ' to do: ' + $steps[$i]) $cx $y 26 26 $WHITE 13 $MUTED 2; $d.ForeColor = $INK; $lf = $MUTED; $lb = $false }
        $d.Text = [string]$n; $d.Font = Fnt 11 $true
        $null = New-Lbl $card $steps[$i] ([int]($x0 + $i * $cw)) ($y + 30) ([int]$cw) 28 11 $lb $lf 'C' $true
    }
    $y += 58 + 12 + 4
    # checks
    $t1 = 'The format check passed in draft mode, 17 Nov 26 0914. See the 0 findings'
    $null = New-Lbl $card $tick $x0 ($y + 2) 20 22 15 $true (C '#2E7D4F')
    $l1 = New-Object System.Windows.Forms.LinkLabel
    $l1.AutoSize = $false; $l1.UseMnemonic = $false; $l1.Text = $t1; $l1.AccessibleName = $t1
    $l1.Font = Fnt 15 $false; $l1.ForeColor = $INK; $l1.LinkColor = $BLUE; $l1.BackColor = [System.Drawing.Color]::Transparent
    $l1.Padding = New-Object System.Windows.Forms.Padding(0)
    $l1.LinkArea = New-Object System.Windows.Forms.LinkArea(($t1.Length - 17), 17)
    $l1.Tag = 'wrap'
    $l1.SetBounds(($x0 + 30), ($y + 2), ($iw - 30), 24)
    $card.Controls.Add($l1)
    $y += 28 + 10
    $t2 = 'I read the draft. It is ready for the offices. Open the draft in Word for the web'
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.AccessibleName = 'I read the draft. It is ready for the offices.'
    $cb.Text = ''; $cb.AutoSize = $false; $cb.BackColor = [System.Drawing.Color]::Transparent
    $cb.SetBounds($x0, ($y + 2), 24, 24)
    $card.Controls.Add($cb)
    $l2 = New-Object System.Windows.Forms.LinkLabel
    $l2.AutoSize = $false; $l2.UseMnemonic = $false; $l2.Text = $t2; $l2.AccessibleName = $t2
    $l2.Font = Fnt 15 $false; $l2.ForeColor = $INK; $l2.LinkColor = $BLUE; $l2.BackColor = [System.Drawing.Color]::Transparent
    $l2.Padding = New-Object System.Windows.Forms.Padding(0)
    $l2.LinkArea = New-Object System.Windows.Forms.LinkArea(($t2.Length - 31), 31)
    $l2.Tag = 'wrap'
    $l2.SetBounds(($x0 + 34), ($y + 3), ($iw - 34), 24)
    $card.Controls.Add($l2)
    $y += 28 + 10
    $t3 = 'As the privacy monitor, I reviewed the draft for personal information (DAFMAN 90-161, 2.8.1).'
    $cb2 = New-Object System.Windows.Forms.CheckBox
    $cb2.AccessibleName = 'As the privacy monitor, I reviewed the draft for personal information.'
    $cb2.Text = ''; $cb2.AutoSize = $false; $cb2.BackColor = [System.Drawing.Color]::Transparent
    $cb2.SetBounds($x0, ($y + 2), 24, 24)
    $card.Controls.Add($cb2)
    $p3 = New-Para $card $t3 ($x0 + 34) ($y + 3) ($iw - 34) 15 $false $INK
    $y += [Math]::Max(28, $p3.Height + 6) + 10 + 6
    # buttons
    $bx = $x0
    foreach ($bt in @(@('Start Endorsement', $true, 16), @('Send Back to the AO', $false, 20), @('Change or Skip', $false, 20))) {
        $bwid = BtnW $bt[0] 15 $bt[1] $bt[2]
        $null = New-Btn $card $bt[0] $bx $y $bwid 44 $bt[1] 15
        $bx += $bwid + 10
    }
    $y += 44 + 12
    $np = New-Para $card 'Start Endorsement asks you to confirm first. Send Back asks for your reason; the AO gets it by e-mail.' $x0 $y $iw 13 $false $MUTED
    $y += $np.Height + 22
    $card.Height = $y

    # side panel
    $ax = $lx + $lw + 22
    $side = New-Box $root 'Action status' $ax 22 $aw ($H - 44) $WHITE 6 $LINE 1
    $sw = $aw - 44
    $null = New-Lbl $side 'ACTION STATUS' 22 20 $sw 16 12 $true $MUTED
    $null = New-Lbl $side 'Sample OI 33-101, Key Control' 22 40 $sw 26 19 $true $NAVY
    $null = New-Lbl $side ('Review ' + $mid + ' step 8 of 12 ' + $mid + ' with you since 16 Nov 26') 22 69 $sw 19 14 $false $MUTED
    $nt = 'Start sends wave 1 to three offices. Due 9 Dec 26: 15 business days, Thanksgiving not counted (DAFMAN 90-161, 5.2).'
    $nh = (TextH $nt (Fnt 14 $false) ($sw - 24)) + 20
    $nb = New-Box $side 'Note' 22 96 $sw $nh $PAGE 4 $null 0
    $null = New-Para $nb $nt 12 10 ($sw - 24) 14 $false $INK
    $yy = 96 + $nh + 12
    $yy += New-CoRow $side 22 $yy $sw 'Wave 1: offices the AO added' '3 named' 'neu' $true
    $yy += New-CoRow $side 22 $yy $sw 'Wave 2: mandatory offices' '5 named' 'neu' $true
    $yy += New-CoRow $side 22 $yy $sw 'Wave 3: legal, last' '1 named' 'neu' $true
    $yy += New-CoRow $side 22 $yy $sw 'AO' 'Sample AO 1' '' $true
    $yy += New-CoRow $side 22 $yy $sw 'Feedback from readers' ('2 people, 28 Oct 26') '' $false
    $null = New-Btn $side 'Full History' 22 ($H - 44 - 20 - 44) $sw 44 $false 15
    $null
}

function Get-Stats($root) {
    $st = @{ n = 0; noName = 0; clipped = 0 }
    $stack = New-Object System.Collections.Stack
    foreach ($c in $root.Controls) { $stack.Push($c) }
    while ($stack.Count -gt 0) {
        $c = $stack.Pop()
        $st.n++
        if ([string]::IsNullOrEmpty($c.AccessibleName)) { $st.noName++ }
        $bad = $false
        $p = $c.Parent
        if ($null -ne $p) {
            $cs = $p.ClientSize
            if ($c.Left -lt 0 -or $c.Top -lt 0 -or $c.Right -gt $cs.Width -or $c.Bottom -gt $cs.Height) { $bad = $true }
        }
        # PreferredSize only where it means something: text controls (wrapping ones at their own width)
        $isText = ($c -is [System.Windows.Forms.Label]) -or ($c -is [System.Windows.Forms.ButtonBase])
        if ($isText -and $c -isnot [System.Windows.Forms.CheckBox]) {
            if ($c.Tag -eq 'wrap') { $ps = $c.GetPreferredSize((New-Object System.Drawing.Size($c.Width, 0))) } else { $ps = $c.PreferredSize }
            if ($ps.Width -gt $c.Width -or $ps.Height -gt $c.Height) { $bad = $true }
        }
        if ($bad) { $st.clipped++ }
        if ($c -isnot [System.Windows.Forms.DataGridView]) {
            foreach ($k in $c.Controls) { $stack.Push($k) }
        }
    }
    $st
}

function Show-Spike([string]$name, [int]$W, [int]$H, [scriptblock]$build) {
    $form = New-Object System.Windows.Forms.Form
    $form.AccessibleName = $name
    $form.FormBorderStyle = 'None'
    $form.StartPosition = 'Manual'
    $form.Location = New-Object System.Drawing.Point(0, 0)
    $form.ShowInTaskbar = $false
    $form.AutoScaleMode = 'None'
    $form.BackColor = $PAGE
    $form.ClientSize = New-Object System.Drawing.Size($W, $H)
    $root = New-Object System.Windows.Forms.Panel
    $root.AccessibleName = $name + ' page'
    $root.BackColor = $PAGE
    $root.Dock = 'Fill'
    $form.Controls.Add($root)
    $grid = & $build $root $W $H
    $form.Show()
    [System.Windows.Forms.Application]::DoEvents()
    if ($grid -is [System.Windows.Forms.DataGridView]) {
        $grid.CurrentCell = $null
        $grid.ClearSelection()
        $grid.Rows[2].Selected = $true
    }
    [System.Windows.Forms.Application]::DoEvents()
    $bmp = New-Object System.Drawing.Bitmap($W, $H)
    $root.DrawToBitmap($bmp, (New-Object System.Drawing.Rectangle(0, 0, $W, $H)))
    $st = Get-Stats $root
    $out = $bmp
    if ($W -gt 1280) {
        $nh = [int]($H * 1280 / $W)
        $out = New-Object System.Drawing.Bitmap(1280, $nh)
        $g = [System.Drawing.Graphics]::FromImage($out)
        $g.InterpolationMode = 'HighQualityBicubic'
        $g.DrawImage($bmp, 0, 0, 1280, $nh)
        $g.Dispose()
    }
    $ms = New-Object System.IO.MemoryStream
    $out.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bytes = $ms.ToArray()
    if ($OutDir) {
        New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
        $bmp.Save((Join-Path $OutDir ($name + '.png')), [System.Drawing.Imaging.ImageFormat]::Png)
    }
    Write-Output ('SPIKE {0} png={1}x{2} controls={3} noAccessibleName={4} clipped={5}' -f $name, $W, $H, $st.n, $st.noName, $st.clipped)
    $b64 = [Convert]::ToBase64String($bytes)
    $i = 0
    for ($o = 0; $o -lt $b64.Length; $o += 4000) {
        $len = [Math]::Min(4000, $b64.Length - $o)
        Write-Output ('PNGB64 {0} {1} {2}' -f $name, $i, $b64.Substring($o, $len))
        $i++
    }
    $form.Close()
    $form.Dispose()
}

Show-Spike 'YourWork-1280x720' 1280 720 { param($r, $w, $h) Build-Home $r $w $h }
Show-Spike 'YourWork-1707x1440' 1707 1440 { param($r, $w, $h) Build-Home $r $w $h }
Show-Spike 'Step8-1280x720' 1280 720 { param($r, $w, $h) Build-Step8 $r $w $h }
