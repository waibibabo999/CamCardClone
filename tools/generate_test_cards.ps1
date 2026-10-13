#Requires -Version 7
<#
  生成 CamCardClone 的测试名片数据集（图片 + Ground Truth）。

  背景：作业第十四节建议教师统一提供 30～50 张测试名片 + Ground Truth，
  但本课程未统一提供，因此需要自行合成。全部使用虚构姓名、example.com 邮箱、
  0000 / 555 号段电话，不含任何真实个人信息。

  用法：
    pwsh -File tools/generate_test_cards.ps1

  输出：
    references/test-images/*.jpg          测试名片图片（含拍摄质量差的变体）
    references/ground-truth/*.json        每张图片对应的 Ground Truth
    references/test-images/README.md      数据集清单（由脚本生成，保持同步）
#>
[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$ImageDir = Join-Path $RepoRoot 'references/test-images'
$TruthDir = Join-Path $RepoRoot 'references/ground-truth'
New-Item -ItemType Directory -Force -Path $ImageDir, $TruthDir | Out-Null

# ---------------------------------------------------------------- 主题（版式 / 字体 / 配色）
$Themes = @(
  @{ Bg='#FFFFFF'; Fg='#1B1B1F'; Muted='#6B7280'; Accent='#1D4ED8'; Band='left'; NameFont='Microsoft YaHei'; BodyFont='Microsoft YaHei'; Label=$true;  Dark=$false; Logo='ring' }
  @{ Bg='#FFFFFF'; Fg='#111827'; Muted='#6B7280'; Accent='#047857'; Band='top';  NameFont='SimHei';          BodyFont='SimHei';          Label=$true;  Dark=$false; Logo='square' }
  @{ Bg='#F3F4F6'; Fg='#111827'; Muted='#4B5563'; Accent='#0F172A'; Band='none'; NameFont='DengXian';        BodyFont='DengXian';        Label=$true;  Dark=$false; Logo='square' }
  @{ Bg='#1B2330'; Fg='#F9FAFB'; Muted='#9CA3AF'; Accent='#D4AF37'; Band='none'; NameFont='Microsoft YaHei'; BodyFont='Microsoft YaHei'; Label=$true;  Dark=$true;  Logo='ring' }
  @{ Bg='#FFFFFF'; Fg='#000000'; Muted='#374151'; Accent='#111111'; Band='none'; NameFont='SimSun';          BodyFont='SimSun';          Label=$false; Dark=$false; Logo='none' }
  @{ Bg='#FBF7EF'; Fg='#3F2E1E'; Muted='#7C6A55'; Accent='#A0522D'; Band='left'; NameFont='KaiTi';           BodyFont='SimSun';          Label=$true;  Dark=$false; Logo='square' }
  @{ Bg='#FFFFFF'; Fg='#1F2937'; Muted='#6B7280'; Accent='#C0392B'; Band='top';  NameFont='SimHei';          BodyFont='Microsoft YaHei'; Label=$true;  Dark=$false; Logo='circle' }
  @{ Bg='#EAF2FB'; Fg='#10233B'; Muted='#4A6076'; Accent='#1B6CA8'; Band='none'; NameFont='FangSong';        BodyFont='Microsoft YaHei'; Label=$true;  Dark=$false; Logo='ring' }
)

# 英文名片换用拉丁字体，增加"不同字体"的覆盖面
$LatinFonts = @('Calibri','Georgia','Times New Roman','Arial','Verdana','Tahoma','Segoe UI','Cambria')

# ---------------------------------------------------------------- 名片数据
# 格式： id | 版式(h/v) | 主题(1-8) | 语言(zh/en/bi) | 字段=值;字段=值...
# 字段： name company jobTitle department mobile phone fax email email2 website postalCode address
$CardSpec = @(
  # ---- 中文名片 ----
  'zh_01|h|1|zh|name=张伟;company=上海远景科技有限公司;jobTitle=技术总监;mobile=+86 138-0013-8000;email=zhangwei@example.com;address=上海市浦东新区世纪大道 100 号 25 层'
  'zh_02|h|2|zh|name=李静怡;company=北京华信医疗科技有限公司;jobTitle=产品经理;mobile=139-0022-4567;phone=010-6688-1234;email=lijingyi@example.com'
  'zh_03|h|6|zh|name=王浩然;company=广州南方贸易有限公司;jobTitle=销售经理;department=销售部;mobile=137-8899-6655;address=广州市天河区华夏路 30 号 1802 室'
  'zh_04|h|7|zh|name=陈美玲;company=深圳市星辰电子有限公司;jobTitle=财务主管;mobile=135-6677-8899;email=chenmeiling@example.com'
  'zh_05|h|3|zh|name=赵国强;company=杭州云图信息技术有限公司;jobTitle=客户服务总监;mobile=136-1122-3344;phone=0571-8899-0011;website=www.yuntu-example.com'
  'zh_06|v|1|zh|name=孙雅婷;company=成都锦江文化传播有限公司;jobTitle=市场策划专员;mobile=158-3344-5566;email=sunyating@example.com;address=成都市武侯区人民南路四段 1 号'

  # ---- 英文名片 ----
  'en_01|h|4|en|name=David Chen;company=ABC Technologies Inc.;jobTitle=Technical Director;mobile=+1-415-555-0142;email=david.chen@example.com;website=www.abc-tech-example.com'
  'en_02|h|5|en|name=Sarah Mitchell;company=Northwind Logistics LLC;jobTitle=Operations Manager;phone=+1-206-555-0177;email=s.mitchell@example.com;address=1200 Harbor Street, Seattle, WA 98101'
  'en_03|h|8|en|name=James Rodriguez;company=Brightline Consulting Group;jobTitle=Senior Consultant;mobile=+1-312-555-0198;email=j.rodriguez@example.com'
  'en_04|h|2|en|name=Emily Watson;company=GreenLeaf Publishing Ltd.;jobTitle=Editorial Director;phone=+44 20 7946 0958;email=emily.watson@example.com;website=www.greenleaf-example.co.uk'
  'en_05|h|1|en|name=Michael Brown;company=Summit Financial Services;jobTitle=Chief Financial Officer;mobile=+1-617-555-0110;fax=+1-617-555-0111;email=m.brown@example.com'
  'en_06|v|5|en|name=Olivia Parker;company=Rivera Design Studio;jobTitle=Art Director;mobile=+1-503-555-0134;email=olivia@example.com;address=88 Pearl Avenue, Suite 400, Portland, OR 97209'

  # ---- 中英双语名片 ----
  'bi_01|h|3|bi|name=朱宏明 Hongming Zhu;company=同济大学 Tongji University;jobTitle=教授 Professor;mobile=+86 138-1234-5678;email=zhuhongming@example.com;address=上海市杨浦区四平路 1239 号'
  'bi_02|h|1|bi|name=林嘉怡 JiaYi Lin;company=环球贸易有限公司 Global Trading Co., Ltd.;jobTitle=国际业务经理 International Sales Manager;mobile=+86 139-8765-4321;phone=021-5566-7788;email=jiayi.lin@example.com'
  'bi_03|h|7|bi|name=郭文博 Wenbo Guo;company=中科智能研究院 CAS Intelligent Research Institute;jobTitle=高级工程师 Senior Engineer;mobile=137-5566-8899;email=wenbo.guo@example.com'
  'bi_04|v|4|bi|name=何晓雪 Xiaoxue He;company=东方艺术中心 Oriental Art Center;jobTitle=艺术总监 Art Director;mobile=138-2233-4455;email=xiaoxue.he@example.com;website=www.oriental-art-example.cn'
  'bi_05|h|6|bi|name=黄志远 Zhiyuan Huang;company=长江航运集团 Yangtze Shipping Group;jobTitle=副总经理 Deputy General Manager;phone=027-8877-6655;mobile=133-4455-6677;address=武汉市江汉区沿江大道 88 号'
  'bi_06|h|8|bi|name=周雅雯 Yawen Zhou;company=华南师范大学 South China Normal University;jobTitle=副教授 Associate Professor;department=计算机学院 School of Computer Science;mobile=135-9988-7766;email=yawen.zhou@example.com'

  # ---- 竖版 / 特殊版式 ----
  'vt_01|v|2|zh|name=徐若彤;company=明月建筑设计事务所;jobTitle=首席设计师;mobile=130-1111-2222;email=ruotong.xu@example.com'
  'vt_02|v|4|en|name=Alan Reed;company=Vertex Media Group;jobTitle=Creative Producer;mobile=+1-718-555-0166;email=a.reed@example.com;website=www.vertexmedia-example.com'
  'vt_03|v|8|bi|name=田明哲 Mingzhe Tian;company=恒星新能源科技 Stellar New Energy;jobTitle=研发经理 R&D Manager;mobile=131-2222-3333;phone=0755-2233-4455;email=mingzhe.tian@example.com'
  'vt_04|v|3|en|name=Priya Sharma;company=Lantern Health Partners;jobTitle=Clinical Research Lead;phone=+91 22 4000 1234;email=priya.sharma@example.com;address=14 Marine Drive, Mumbai 400020'

  # ---- 多电话 / 多 Email ----
  'mp_01|h|2|zh|name=罗建华;company=中远精密制造有限公司;jobTitle=生产部经理;mobile=136-5555-6666;phone=0512-6677-8899;fax=0512-6677-8800;email=luojianhua@example.com;email2=jh.luo@example.com'
  'mp_02|h|5|en|name=Robert Klein;company=Interlink Supply Co.;jobTitle=Regional Sales Lead;mobile=+1-404-555-0123;phone=+1-404-555-0120;fax=+1-404-555-0121;email=r.klein@example.com;email2=sales.klein@example.com'
  'mp_03|h|1|bi|name=沈丽娜 Lina Shen;company=广达物流有限公司 Quanta Logistics;jobTitle=调度中心主管;mobile=138-7777-8888;phone=020-3344-5566;fax=020-3344-5500;email=lina.shen@example.com'
  'mp_04|h|7|zh|name=蔡文杰;company=天工机械制造有限公司;jobTitle=售后服务经理;mobile=137-3000-4000;phone=0532-8899-1122;fax=0532-8899-1100;email=caiwenjie@example.com'

  # ---- 字段缺失（T09 专用）----
  'ms_01|h|2|zh|name=高静;company=汇文图书发行有限公司;jobTitle=发行主管;mobile=135-1234-0000'
  'ms_02|h|5|en|name=Nathan Cole;company=Cole & Partners LLP;jobTitle=Partner;phone=+1-212-555-0188'
  'ms_03|h|3|zh|name=汪思远;company=汇智教育科技有限公司;jobTitle=课程顾问;mobile=150-6000-7000;email=wangsiyuan@example.com'
  'ms_04|v|8|en|name=Grace Lin;company=Bluepeak Analytics;jobTitle=Data Scientist;email=grace.lin@example.com'

  # ---- 复杂 Logo / 背景 ----
  'cx_01|h|7|zh|name=孟繁星;company=星河数字娱乐有限公司;jobTitle=游戏美术总监;mobile=139-2222-1111;email=mengfanxing@example.com;website=www.xinghe-game-example.com'
  'cx_02|h|4|en|name=Thomas Wright;company=Orbit Aerospace Systems;jobTitle=Systems Architect;mobile=+1-303-555-0155;email=t.wright@example.com'
  'cx_03|h|6|zh|name=董雅琪;company=花漾生活家装饰设计;jobTitle=设计总监;mobile=136-8888-9999;email=dongyaqi@example.com'
  'cx_04|h|8|en|name=Daniel Osei;company=Meridian Trading Partners;jobTitle=Import Manager;phone=+233 30 123 4567;email=d.osei@example.com'
)

# 拍摄质量差的变体： 源名片 | 编号 | 背景 | 旋转角 | 纵向压缩 | JPEG 质量
$PhotoVariants = @(
  @{ Src='zh_01'; Id='px_01'; Bg='light'; Angle=-3.5; Squash=0.90; Quality=80 }
  @{ Src='zh_04'; Id='px_02'; Bg='desk';  Angle=6.0;  Squash=0.82; Quality=74 }
  @{ Src='en_02'; Id='px_03'; Bg='dark';  Angle=-1.5; Squash=0.95; Quality=78 }
  @{ Src='en_05'; Id='px_04'; Bg='busy';  Angle=4.0;  Squash=0.86; Quality=72 }
  @{ Src='bi_02'; Id='px_05'; Bg='desk';  Angle=0.8;  Squash=0.99; Quality=70 }
  @{ Src='vt_02'; Id='px_06'; Bg='light'; Angle=-8.0; Squash=0.88; Quality=76 }
  @{ Src='cx_01'; Id='px_07'; Bg='busy';  Angle=2.5;  Squash=0.93; Quality=68 }
  @{ Src='ms_03'; Id='px_08'; Bg='dark';  Angle=-5.0; Squash=0.90; Quality=74 }
)

$FieldOrder = @('name','company','jobTitle','department','mobile','phone','fax','email','email2','website','postalCode','address')
$LineOrder  = @('mobile','phone','fax','email','email2','website','department','postalCode','address')
$LabelsZh = @{ mobile='手机'; phone='电话'; fax='传真'; email='邮箱'; email2='邮箱'; website='网址'; department='部门'; postalCode='邮编'; address='地址' }
$LabelsEn = @{ mobile='Mobile'; phone='Tel'; fax='Fax'; email='Email'; email2='Email'; website='Web'; department='Dept'; postalCode='Zip'; address='Address' }

function Get-Color([string]$Hex) { [System.Drawing.ColorTranslator]::FromHtml($Hex) }

function Draw-Text {
  param(
    [System.Drawing.Graphics]$G, [string]$Text, [string]$Family, [float]$Size,
    [string]$ColorHex, [float]$X, [float]$Y, [string]$Style = 'Regular',
    [switch]$Center, [float]$BoxWidth = 0
  )
  if ([string]::IsNullOrWhiteSpace($Text)) { return }
  $styleEnum = [System.Enum]::Parse([System.Drawing.FontStyle], $Style)
  $font  = [System.Drawing.Font]::new($Family, $Size, $styleEnum, [System.Drawing.GraphicsUnit]::Pixel)
  $brush = [System.Drawing.SolidBrush]::new((Get-Color $ColorHex))
  if ($Center) {
    $sf = [System.Drawing.StringFormat]::new()
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $rect = [System.Drawing.RectangleF]::new($X, $Y, $BoxWidth, $Size * 1.8)
    $G.DrawString($Text, $font, $brush, $rect, $sf)
    $sf.Dispose()
  } else {
    $G.DrawString($Text, $font, $brush, $X, $Y)
  }
  $font.Dispose()
  $brush.Dispose()
}

function Draw-Logo {
  param([System.Drawing.Graphics]$G, $Theme, [string]$Company, [System.Drawing.RectangleF]$Box, [switch]$Complex)
  $accent = Get-Color $Theme.Accent
  $cx = $Box.X + $Box.Width / 2
  $cy = $Box.Y + $Box.Height / 2
  $r  = [Math]::Min($Box.Width, $Box.Height) / 2

  if ($Complex) {
    for ($i = 0; $i -lt 3; $i++) {
      $alpha = 30 + 25 * $i
      $b = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb($alpha, $accent))
      $rr = $r * (1.25 - 0.25 * $i)
      $G.FillEllipse($b, [float]($cx - $rr + $i * 40), [float]($cy - $rr - $i * 30), [float]($rr * 2), [float]($rr * 2))
      $b.Dispose()
    }
    $pts = @(
      [System.Drawing.PointF]::new([float]($cx - $r * 1.4), [float]($cy + $r * 0.9)),
      [System.Drawing.PointF]::new([float]($cx - $r * 0.2), [float]($cy - $r * 1.2)),
      [System.Drawing.PointF]::new([float]($cx + $r * 1.5), [float]($cy + $r * 0.4)),
      [System.Drawing.PointF]::new([float]($cx + $r * 0.2), [float]($cy + $r * 1.3))
    )
    $pb = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(70, $accent))
    $G.FillPolygon($pb, $pts)
    $pb.Dispose()
  }

  switch ($Theme.Logo) {
    'ring' {
      $pen = [System.Drawing.Pen]::new($accent, 10)
      $G.DrawEllipse($pen, [float]($cx - $r * 0.8), [float]($cy - $r * 0.8), [float]($r * 1.6), [float]($r * 1.6))
      $pen.Dispose()
    }
    'circle' {
      $b = [System.Drawing.SolidBrush]::new($accent)
      $G.FillEllipse($b, [float]($cx - $r * 0.85), [float]($cy - $r * 0.85), [float]($r * 1.7), [float]($r * 1.7))
      $b.Dispose()
    }
    'square' {
      $b = [System.Drawing.SolidBrush]::new($accent)
      $G.FillRectangle($b, [float]($cx - $r * 0.75), [float]($cy - $r * 0.75), [float]($r * 1.5), [float]($r * 1.5))
      $b.Dispose()
    }
    default { return }
  }

  if (-not [string]::IsNullOrWhiteSpace($Company)) {
    $initial = $Company.Substring(0, 1).ToUpper()
    $fill = if ($Theme.Dark -or $Theme.Logo -ne 'ring') { '#FFFFFF' } else { $Theme.Accent }
    $boxWidth = $r * 3
    Draw-Text -G $G -Text $initial -Family $Theme.NameFont -Size ($r * 0.75) -ColorHex $fill `
      -X ($cx - $boxWidth / 2) -Y ($cy - $r * 0.62) -Center -BoxWidth $boxWidth
  }
}

function New-CardImage {
  param([string]$Id, [string]$Layout, [int]$ThemeIndex, [string]$Lang, [hashtable]$Fields, [switch]$Complex)

  $theme = $Themes[($ThemeIndex - 1) % $Themes.Count]
  if ($Layout -eq 'v') { $W = 880; $H = 1400 } else { $W = 1400; $H = 880 }

  $bmp = [System.Drawing.Bitmap]::new($W, $H)
  $g   = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

  $bgBrush = [System.Drawing.SolidBrush]::new((Get-Color $theme.Bg))
  $g.FillRectangle($bgBrush, 0, 0, $W, $H)
  $bgBrush.Dispose()

  $accent = Get-Color $theme.Accent
  if ($theme.Band -eq 'left') {
    $b = [System.Drawing.SolidBrush]::new($accent); $g.FillRectangle($b, 0, 0, 18, $H); $b.Dispose()
  } elseif ($theme.Band -eq 'top') {
    $b = [System.Drawing.SolidBrush]::new($accent); $g.FillRectangle($b, 0, 0, $W, 16); $b.Dispose()
  }

  if ($Complex) {
    for ($i = 0; $i -lt 5; $i++) {
      $b = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(18, $accent))
      $g.FillEllipse($b, (-120 + $i * 260), ($H - 260 + ($i % 2) * -70), 320, 320)
      $b.Dispose()
    }
  }

  $nameFont = $theme.NameFont
  $bodyFont = $theme.BodyFont
  if ($Lang -eq 'en') {
    $nameFont = $LatinFonts[($ThemeIndex - 1) % $LatinFonts.Count]
    $bodyFont = $LatinFonts[(($ThemeIndex + 3) % $LatinFonts.Count)]
  }

  $labels = if ($Lang -eq 'en') { $LabelsEn } else { $LabelsZh }
  $showLabel = $theme.Label

  if ($Layout -eq 'v') {
    $pad = 90
    Draw-Logo -G $g -Theme $theme -Company $Fields['company'] `
      -Box ([System.Drawing.RectangleF]::new(($W / 2 - 110), 150, 220, 220)) -Complex:$Complex

    $y = 470
    Draw-Text -G $g -Text $Fields['name'] -Family $nameFont -Size 60 -ColorHex $theme.Fg `
      -X $pad -Y $y -Style Bold -Center -BoxWidth ($W - $pad * 2); $y += 92
    Draw-Text -G $g -Text $Fields['jobTitle'] -Family $bodyFont -Size 34 -ColorHex $theme.Muted `
      -X $pad -Y $y -Center -BoxWidth ($W - $pad * 2); $y += 60
    Draw-Text -G $g -Text $Fields['company'] -Family $bodyFont -Size 36 -ColorHex $theme.Accent `
      -X $pad -Y $y -Style Bold -Center -BoxWidth ($W - $pad * 2); $y += 74

    $pen = [System.Drawing.Pen]::new($accent, 3)
    $g.DrawLine($pen, ($pad + 180), $y, ($W - $pad - 180), $y)
    $pen.Dispose(); $y += 46

    foreach ($key in $LineOrder) {
      $val = $Fields[$key]
      if ([string]::IsNullOrWhiteSpace($val)) { continue }
      $text = if ($showLabel) { "$($labels[$key])：$val" } else { $val }
      Draw-Text -G $g -Text $text -Family $bodyFont -Size 28 -ColorHex $theme.Muted `
        -X $pad -Y $y -Center -BoxWidth ($W - $pad * 2)
      $y += 54
    }
  } else {
    $pad = 90
    Draw-Logo -G $g -Theme $theme -Company $Fields['company'] `
      -Box ([System.Drawing.RectangleF]::new(($W - 380), 300, 300, 300)) -Complex:$Complex

    $y = 160
    Draw-Text -G $g -Text $Fields['name'] -Family $nameFont -Size 66 -ColorHex $theme.Fg -X $pad -Y $y -Style Bold; $y += 96
    Draw-Text -G $g -Text $Fields['jobTitle'] -Family $bodyFont -Size 32 -ColorHex $theme.Muted -X $pad -Y $y; $y += 54
    Draw-Text -G $g -Text $Fields['company'] -Family $bodyFont -Size 40 -ColorHex $theme.Accent -X $pad -Y $y -Style Bold; $y += 62

    $pen = [System.Drawing.Pen]::new($accent, 3)
    $g.DrawLine($pen, $pad, $y, ($pad + 420), $y)
    $pen.Dispose(); $y += 40

    foreach ($key in $LineOrder) {
      $val = $Fields[$key]
      if ([string]::IsNullOrWhiteSpace($val)) { continue }
      $text = if ($showLabel) { "$($labels[$key])：$val" } else { $val }
      Draw-Text -G $g -Text $text -Family $bodyFont -Size 28 -ColorHex $theme.Muted -X $pad -Y $y
      $y += 50
    }
  }

  $g.Dispose()
  return $bmp
}

function Save-Jpeg {
  param([System.Drawing.Bitmap]$Bitmap, [string]$Path, [int]$Quality = 92)
  $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
  $eps = [System.Drawing.Imaging.EncoderParameters]::new(1)
  $eps.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new([System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)
  $Bitmap.Save($Path, $codec, $eps)
  $eps.Dispose()
}

function New-PhotoVariant {
  param(
    [System.Drawing.Bitmap]$Card, [string]$Bg, [double]$Angle, [double]$Squash,
    [int]$Quality, [string]$Path
  )

  $CW = 1600; $CH = 1200
  $canvas = [System.Drawing.Bitmap]::new($CW, $CH)
  $g = [System.Drawing.Graphics]::FromImage($canvas)
  $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

  switch ($Bg) {
    'dark'  { $c1 = Get-Color '#101418'; $c2 = Get-Color '#05070A' }
    'light' { $c1 = Get-Color '#F8FAFC'; $c2 = Get-Color '#CBD5E1' }
    'busy'  { $c1 = Get-Color '#8C6E52'; $c2 = Get-Color '#4A3626' }
    default { $c1 = Get-Color '#6B7280'; $c2 = Get-Color '#374151' }
  }

  $rect = [System.Drawing.Rectangle]::new(0, 0, $CW, $CH)
  $lb = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
    $rect, $c1, $c2, [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal)
  $g.FillRectangle($lb, 0, 0, $CW, $CH)
  $lb.Dispose()

  if ($Bg -eq 'busy') {
    $rnd = [System.Random]::new(20261012)
    for ($i = 0; $i -lt 14; $i++) {
      $col = [System.Drawing.Color]::FromArgb(90, $rnd.Next(60, 220), $rnd.Next(60, 200), $rnd.Next(50, 190))
      $b = [System.Drawing.SolidBrush]::new($col)
      $g.FillRectangle($b, $rnd.Next(0, $CW), $rnd.Next(0, $CH), $rnd.Next(80, 420), $rnd.Next(60, 340))
      $b.Dispose()
    }
  }

  $scale = 0.60
  $w = $Card.Width * $scale
  $h = $Card.Height * $scale

  $g.TranslateTransform($CW / 2, $CH / 2)
  $g.RotateTransform([float]$Angle)
  $g.ScaleTransform(1.0, [float]$Squash)

  $shadow = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(90, 0, 0, 0))
  $g.FillRectangle($shadow, [float](-$w / 2 + 16), [float](-$h / 2 + 20), [float]$w, [float]$h)
  $shadow.Dispose()
  $g.DrawImage($Card, [float](-$w / 2), [float](-$h / 2), [float]$w, [float]$h)

  $g.ResetTransform()
  $gl = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
    $rect,
    [System.Drawing.Color]::FromArgb(0, 0, 0, 0),
    [System.Drawing.Color]::FromArgb(130, 0, 0, 0),
    [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal)
  $g.FillRectangle($gl, 0, 0, $CW, $CH)
  $gl.Dispose()
  $g.Dispose()

  Save-Jpeg -Bitmap $canvas -Path $Path -Quality $Quality
  $canvas.Dispose()
}

# ---------------------------------------------------------------- 主流程
$generated = @()
$bitmaps   = @{}

foreach ($spec in $CardSpec) {
  $parts    = $spec -split '\|'
  $id       = $parts[0]
  $layout   = $parts[1]
  $themeIdx = [int]$parts[2]
  $lang     = $parts[3]

  $fields = @{}
  foreach ($kv in ($parts[4] -split ';')) {
    if ([string]::IsNullOrWhiteSpace($kv)) { continue }
    $i = $kv.IndexOf('=')
    $fields[$kv.Substring(0, $i)] = $kv.Substring($i + 1)
  }

  $complex = $id.StartsWith('cx_')
  $bmp = New-CardImage -Id $id -Layout $layout -ThemeIndex $themeIdx -Lang $lang -Fields $fields -Complex:$complex
  $bitmaps[$id] = $bmp
  Save-Jpeg -Bitmap $bmp -Path (Join-Path $ImageDir "$id.jpg") -Quality 92

  $truth = [ordered]@{
    id = $id; name = $null; company = $null; jobTitle = $null; department = $null
    mobile = $null; phone = $null; fax = $null; email = $null; website = $null
    address = $null; postalCode = $null; notes = $null
  }
  foreach ($key in $FieldOrder) {
    if ($key -eq 'email2') { continue }
    if ($fields.ContainsKey($key)) { $truth[$key] = $fields[$key] }
  }
  if ($fields.ContainsKey('email2')) { $truth['additionalEmails'] = @($fields['email2']) }
  $truth | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $TruthDir "$id.json") -Encoding utf8

  $generated += [pscustomobject]@{
    Id = $id; Layout = $layout; Lang = $lang; Theme = $themeIdx
    Category = ($id -split '_')[0]; Source = $id
  }
}

foreach ($v in $PhotoVariants) {
  $src = $bitmaps[$v.Src]
  if (-not $src) { Write-Warning "缺少源名片 $($v.Src)，跳过 $($v.Id)"; continue }

  New-PhotoVariant -Card $src -Bg $v.Bg -Angle $v.Angle -Squash $v.Squash -Quality $v.Quality `
    -Path (Join-Path $ImageDir "$($v.Id).jpg")

  $base = $generated | Where-Object { $_.Id -eq $v.Src }
  $truth = Get-Content (Join-Path $TruthDir "$($v.Src).json") -Raw -Encoding utf8 | ConvertFrom-Json
  $truth.id = $v.Id
  $truth | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $TruthDir "$($v.Id).json") -Encoding utf8

  $generated += [pscustomobject]@{
    Id = $v.Id; Layout = $base.Layout; Lang = $base.Lang; Theme = '-'
    Category = 'px'; Source = $v.Src
  }
}

foreach ($b in $bitmaps.Values) { $b.Dispose() }

$categoryName = @{
  zh = '中文名片'; en = '英文名片'; bi = '中英双语'; vt = '竖版 / 特殊版式'
  mp = '多电话 / 多 Email'; ms = '字段缺失'; cx = '复杂 Logo / 背景'; px = '拍摄质量差（由源名片生成）'
}

$rows = foreach ($group in ($generated | Group-Object Category | Sort-Object Name)) {
  $ids = ($group.Group | ForEach-Object { '`' + $_.Id + '`' }) -join ' '
  "| $($categoryName[$group.Name]) | $($group.Count) | $ids |"
}

$readmeTemplate = @'
# 测试名片数据集

本目录由 `tools/generate_test_cards.ps1` 生成。**不要手工修改图片**，需要调整请改脚本后重新运行。

全部数据均为虚构：姓名虚构、邮箱使用 `example.com`、电话使用 `0000` 或 `555` 号段，不含真实个人信息。
每张图片在 `../ground-truth/` 下有同名 JSON。

## 组成（共 {{COUNT}} 张）

| 类型 | 张数 | 编号 |
|---|---|---|
{{ROWS}}

## 命名与用途

| 前缀 | 用途 |
|---|---|
| `zh_` `en_` `bi_` | T07 / T08 基本 OCR 与字段解析 |
| `vt_` | 竖版版式，测试版面方向判断 |
| `mp_` | T10 多电话 / 多 Email |
| `ms_` | T09 字段缺失，验证系统不虚构字段 |
| `cx_` | 复杂 Logo / 背景，测试抗干扰能力 |
| `px_` | T06 倾斜 / 阴影 / 暗背景 / 杂物桌面，用于区域检测与校正 |

## Ground Truth 说明

字段与 `design/data-model.md` 的 GroundTruth 一致：`id` 加 13 个字段，名片上不存在的字段为 `null`。
`notes` 恒为 `null`，因为备注是用户在 App 内添加的，名片上不会印。

`mp_01` / `mp_02` 印有两个邮箱，额外用 `additionalEmails` 数组记录。
当前 `BusinessCard` 数据模型只有单个 `email` 字段，**无法承载多邮箱**，需要先改数据模型或在报告里说明取舍。

## 使用方式

- 相册导入 / 模拟器测试：直接把 `.jpg` 拖进模拟器的"照片"App。
- 相机拍摄测试：把图片显示在笔记本或显示器上，再用 iPhone 拍摄，即可得到带倾斜、阴影、反光的真实照片。
- 注意：`px_` 系列用仿射变换近似"斜拍"，并非真正的透视投影。
'@

$readme = $readmeTemplate.Replace('{{COUNT}}', "$($generated.Count)").Replace('{{ROWS}}', ($rows -join [Environment]::NewLine))
$readme | Set-Content -Path (Join-Path $ImageDir 'README.md') -Encoding utf8

Write-Host "生成完成：$($generated.Count) 张图片 -> $ImageDir"
