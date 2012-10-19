object MainForm: TMainForm
  Left = 79
  Height = 598
  Top = 63
  Width = 722
  Caption = 'Polygon Renderer Benchmark'
  ClientHeight = 598
  ClientWidth = 722
  Color = clBtnFace
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  OnCreate = FormCreate
  Position = poDesktopCenter
  LCLVersion = '0.9.31'
  object PnlTop: TPanel
    Left = 0
    Height = 364
    Top = 0
    Width = 722
    Align = alClient
    BevelOuter = bvNone
    BorderWidth = 10
    ClientHeight = 364
    ClientWidth = 722
    TabOrder = 0
    object Img: TImage32
      Left = 10
      Height = 344
      Top = 10
      Width = 702
      Align = alClient
      Bitmap.ResamplerClassName = 'TNearestResampler'
      BitmapAlign = baTopLeft
      Scale = 1
      ScaleMode = smNormal
      TabOrder = 0
      OnResize = ImgResize
    end
  end
  object PnlBottom: TPanel
    Left = 0
    Height = 234
    Top = 364
    Width = 722
    Align = alBottom
    BevelOuter = bvNone
    BorderWidth = 10
    ClientHeight = 234
    ClientWidth = 722
    TabOrder = 1
    object GbxSettings: TGroupBox
      Left = 10
      Height = 214
      Top = 10
      Width = 328
      Align = alLeft
      Caption = 'Benchmark Settings'
      ClientHeight = 196
      ClientWidth = 324
      TabOrder = 0
      object LblTest: TLabel
        Left = 14
        Height = 14
        Top = 34
        Width = 26
        Caption = '&Test:'
        Color = clBtnFace
        FocusControl = CmbTest
        ParentColor = False
        Transparent = False
      end
      object LblRenderer: TLabel
        Left = 14
        Height = 14
        Top = 61
        Width = 50
        Caption = '&Renderer:'
        Color = clBtnFace
        FocusControl = CmbRenderer
        ParentColor = False
        Transparent = False
      end
      object BtnBenchmark: TButton
        Left = 14
        Height = 25
        Top = 158
        Width = 139
        Caption = 'Do Benchmark'
        OnClick = BtnBenchmarkClick
        TabOrder = 0
      end
      object CmbTest: TComboBox
        Left = 78
        Height = 21
        Top = 31
        Width = 225
        ItemHeight = 13
        Style = csDropDownList
        TabOrder = 1
      end
      object CmbRenderer: TComboBox
        Left = 78
        Height = 21
        Top = 58
        Width = 225
        ItemHeight = 13
        Style = csDropDownList
        TabOrder = 2
      end
      object CbxAllTests: TCheckBox
        Left = 14
        Height = 19
        Top = 98
        Width = 112
        Caption = 'Benchmark all tests'
        TabOrder = 3
      end
      object CbxAllRenderers: TCheckBox
        Left = 14
        Height = 19
        Top = 122
        Width = 135
        Caption = 'Benchmark all renderers'
        TabOrder = 4
      end
      object BtnExit: TButton
        Left = 158
        Height = 25
        Top = 158
        Width = 139
        Cancel = True
        Caption = 'E&xit'
        OnClick = BtnExitClick
        TabOrder = 5
      end
    end
    object GbxResults: TGroupBox
      Left = 348
      Height = 214
      Top = 10
      Width = 364
      Align = alClient
      Caption = 'Benchmark Results'
      ClientHeight = 196
      ClientWidth = 360
      TabOrder = 1
      object PnlBenchmark: TPanel
        Left = 0
        Height = 196
        Top = 0
        Width = 360
        Align = alClient
        BevelOuter = bvNone
        BorderWidth = 10
        ClientHeight = 196
        ClientWidth = 360
        TabOrder = 0
        object MemoLog: TMemo
          Left = 10
          Height = 176
          Top = 10
          Width = 340
          Align = alClient
          Font.CharSet = ANSI_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Courier New'
          Font.Pitch = fpFixed
          Font.Quality = fqDraft
          ParentFont = False
          TabOrder = 0
        end
      end
    end
    object PnlSpacer: TPanel
      Left = 338
      Height = 214
      Top = 10
      Width = 10
      Align = alLeft
      BevelOuter = bvNone
      TabOrder = 2
    end
  end
end
