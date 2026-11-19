object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'TriboContact - Layered Contact Mechanics'
  ClientHeight = 840
  ClientWidth = 1384
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = MainMenu1
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object pnlToolbar: TRzPanel
    AlignWithMargins = True
    Left = 4
    Top = 4
    Width = 1376
    Height = 42
    Align = alTop
    BorderOuter = fsFlatRounded
    TabOrder = 0
    object btnOpen: TRzButton
      AlignWithMargins = True
      Left = 6
      Top = 6
      Width = 86
      Height = 30
      Align = alLeft
      Caption = 'Open Case'
      TabOrder = 0
      OnClick = btnOpenClick
    end
    object btnSave: TRzButton
      AlignWithMargins = True
      Left = 98
      Top = 6
      Width = 86
      Height = 30
      Align = alLeft
      Caption = 'Save Case'
      TabOrder = 1
      OnClick = btnSaveClick
    end
    object btnSolve: TRzButton
      AlignWithMargins = True
      Left = 190
      Top = 6
      Width = 96
      Height = 30
      Align = alLeft
      Caption = 'Run Solve'
      TabOrder = 2
      OnClick = btnSolveClick
    end
    object btnCancel: TRzButton
      AlignWithMargins = True
      Left = 292
      Top = 6
      Width = 76
      Height = 30
      Align = alLeft
      Caption = 'Cancel'
      Enabled = False
      TabOrder = 3
      OnClick = btnCancelClick
    end
    object btnSweep: TRzButton
      AlignWithMargins = True
      Left = 374
      Top = 6
      Width = 98
      Height = 30
      Align = alLeft
      Caption = 'Load Sweep'
      TabOrder = 4
      OnClick = btnSweepClick
    end
    object btnMaterials: TRzButton
      AlignWithMargins = True
      Left = 478
      Top = 6
      Width = 114
      Height = 30
      Align = alLeft
      Caption = 'Materials Library'
      TabOrder = 5
      OnClick = btnMaterialsClick
    end
    object btnExportData: TRzButton
      AlignWithMargins = True
      Left = 598
      Top = 6
      Width = 96
      Height = 30
      Align = alLeft
      Caption = 'Export Data'
      TabOrder = 6
      OnClick = btnExportDataClick
    end
    object btnExportPlots: TRzButton
      AlignWithMargins = True
      Left = 700
      Top = 6
      Width = 96
      Height = 30
      Align = alLeft
      Caption = 'Export Plots'
      TabOrder = 7
      OnClick = btnExportPlotsClick
    end
    object btnSetupCcx: TRzButton
      AlignWithMargins = True
      Left = 802
      Top = 6
      Width = 110
      Height = 30
      Align = alLeft
      Caption = 'Setup CalculiX'
      TabOrder = 8
      OnClick = btnSetupCcxClick
    end
    object btnHelp: TRzButton
      AlignWithMargins = True
      Left = 918
      Top = 6
      Width = 72
      Height = 30
      Align = alLeft
      Caption = 'Help'
      TabOrder = 9
      OnClick = btnHelpClick
    end
  end
  object stsBar: TRzStatusBar
    Left = 0
    Top = 814
    Width = 1384
    Height = 26
    BorderOuter = fsFlatRounded
    TabOrder = 1
    object stpStatus: TRzStatusPane
      AlignWithMargins = True
      Left = 4
      Top = 3
      Width = 880
      Height = 20
      Align = alClient
      Caption = 'Ready'
    end
    object stpCcx: TRzStatusPane
      AlignWithMargins = True
      Left = 890
      Top = 3
      Width = 310
      Height = 20
      Align = alRight
      Caption = 'CalculiX: checking...'
    end
    object stpRuntime: TRzStatusPane
      AlignWithMargins = True
      Left = 1206
      Top = 3
      Width = 172
      Height = 20
      Align = alRight
      Caption = 'Runtime: -'
    end
  end
  object splMain: TRzSplitter
    AlignWithMargins = True
    Left = 4
    Top = 52
    Width = 1376
    Height = 758
    Position = 438
    Percent = 32
    RealTimeDrag = True
    SplitterWidth = 5
    Align = alClient
    BorderOuter = fsFlatRounded
    TabOrder = 2
    BarSize = (
      438
      0
      443
      758)
    UpperLeftControls = (
      scrInputs)
    LowerRightControls = (
      pnlRight)
    object scrInputs: TScrollBox
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 430
      Height = 750
      Align = alClient
      BorderStyle = bsNone
      TabOrder = 0
      object gbBall: TRzGroupBox
        AlignWithMargins = True
        Left = 4
        Top = 4
        Width = 406
        Height = 178
        Align = alTop
        BorderOuter = fsFlatRounded
        Caption = 'Indenter Ball'
        TabOrder = 0
        object lblCaseName: TLabel
          Left = 12
          Top = 24
          Width = 66
          Height = 15
          Caption = 'Case Name:'
        end
        object lblBallPreset: TLabel
          Left = 12
          Top = 54
          Width = 66
          Height = 15
          Caption = 'Ball Preset:'
        end
        object lblBallSize: TLabel
          Left = 12
          Top = 84
          Width = 56
          Height = 15
          Caption = 'Ball Size:'
        end
        object lblBallE: TLabel
          Left = 12
          Top = 114
          Width = 50
          Height = 15
          Caption = 'E (GPa):'
        end
        object lblBallNu: TLabel
          Left = 186
          Top = 114
          Width = 22
          Height = 15
          Caption = 'nu:'
        end
        object edtCaseName: TRzEdit
          Left = 96
          Top = 20
          Width = 294
          Height = 23
          TabOrder = 0
        end
        object cbBallPreset: TRzComboBox
          Left = 96
          Top = 50
          Width = 294
          Height = 23
          Style = csDropDownList
          TabOrder = 1
          OnChange = cbBallPresetChange
        end
        object edtBallSize: TRzEdit
          Left = 96
          Top = 80
          Width = 148
          Height = 23
          TabOrder = 2
        end
        object cbBallSizeMode: TRzComboBox
          Left = 250
          Top = 80
          Width = 140
          Height = 23
          Style = csDropDownList
          TabOrder = 3
          OnChange = cbBallSizeModeChange
          Items.Strings = (
            'Diameter (mm)'
            'Radius (mm)'
            'Radius (um)')
          ItemIndex = 0
        end
        object edtBallE: TRzEdit
          Left = 96
          Top = 110
          Width = 82
          Height = 23
          TabOrder = 4
        end
        object edtBallNu: TRzEdit
          Left = 214
          Top = 110
          Width = 66
          Height = 23
          TabOrder = 5
        end
        object chkBallRigid: TRzCheckBox
          Left = 292
          Top = 113
          Width = 96
          Height = 17
          Caption = 'Rigid Ball'
          TabOrder = 6
        end
      end
      object gbLoad: TRzGroupBox
        AlignWithMargins = True
        Left = 4
        Top = 188
        Width = 406
        Height = 96
        Align = alTop
        BorderOuter = fsFlatRounded
        Caption = 'Load & Friction'
        TabOrder = 1
        object lblNormalLoad: TLabel
          Left = 12
          Top = 26
          Width = 74
          Height = 15
          Caption = 'Normal Load:'
        end
        object lblFriction: TLabel
          Left = 12
          Top = 58
          Width = 74
          Height = 15
          Caption = 'Friction mu:'
        end
        object edtNormalLoad: TRzEdit
          Left = 96
          Top = 22
          Width = 190
          Height = 23
          TabOrder = 0
        end
        object cbLoadUnit: TRzComboBox
          Left = 294
          Top = 22
          Width = 96
          Height = 23
          Style = csDropDownList
          TabOrder = 1
          OnChange = cbLoadUnitChange
          Items.Strings = (
            'N'
            'mN')
          ItemIndex = 0
        end
        object edtFriction: TRzEdit
          Left = 96
          Top = 54
          Width = 190
          Height = 23
          TabOrder = 2
        end
      end
      object gbLayers: TRzGroupBox
        AlignWithMargins = True
        Left = 4
        Top = 290
        Width = 406
        Height = 200
        Align = alTop
        BorderOuter = fsFlatRounded
        Caption = 'Coating Stack (Top to Bottom)'
        TabOrder = 2
        object lvLayers: TListView
          AlignWithMargins = True
          Left = 6
          Top = 20
          Width = 394
          Height = 132
          Align = alClient
          Columns = <
            item
              Caption = '#'
              Width = 28
            end
            item
              Caption = 'Material'
              Width = 95
            end
            item
              Caption = 'h (um)'
              Width = 65
            end
            item
              Caption = 'E (GPa)'
              Width = 65
            end
            item
              Caption = 'nu'
              Width = 48
            end
            item
              Caption = 'sigma_y'
              Width = 62
            end>
          GridLines = True
          HideSelection = False
          ReadOnly = True
          RowSelect = True
          TabOrder = 0
          ViewStyle = vsReport
          OnDblClick = btnLayerEditClick
        end
        object pnlLayerBtns: TRzPanel
          AlignWithMargins = True
          Left = 6
          Top = 158
          Width = 394
          Height = 36
          Align = alBottom
          BorderOuter = fsFlatRounded
          TabOrder = 1
          object btnLayerAdd: TRzButton
            AlignWithMargins = True
            Left = 5
            Top = 5
            Width = 64
            Height = 26
            Align = alLeft
            Caption = 'Add...'
            TabOrder = 0
            OnClick = btnLayerAddClick
          end
          object btnLayerEdit: TRzButton
            AlignWithMargins = True
            Left = 75
            Top = 5
            Width = 64
            Height = 26
            Align = alLeft
            Caption = 'Edit...'
            TabOrder = 1
            OnClick = btnLayerEditClick
          end
          object btnLayerDel: TRzButton
            AlignWithMargins = True
            Left = 145
            Top = 5
            Width = 68
            Height = 26
            Align = alLeft
            Caption = 'Remove'
            TabOrder = 2
            OnClick = btnLayerDelClick
          end
          object btnLayerUp: TRzButton
            AlignWithMargins = True
            Left = 219
            Top = 5
            Width = 52
            Height = 26
            Align = alLeft
            Caption = 'Up'
            TabOrder = 3
            OnClick = btnLayerUpClick
          end
          object btnLayerDown: TRzButton
            AlignWithMargins = True
            Left = 277
            Top = 5
            Width = 56
            Height = 26
            Align = alLeft
            Caption = 'Down'
            TabOrder = 4
            OnClick = btnLayerDownClick
          end
        end
      end
      object gbSubstrate: TRzGroupBox
        AlignWithMargins = True
        Left = 4
        Top = 496
        Width = 406
        Height = 190
        Align = alTop
        BorderOuter = fsFlatRounded
        Caption = 'Substrate'
        TabOrder = 3
        object lblSubPreset: TLabel
          Left = 12
          Top = 26
          Width = 64
          Height = 15
          Caption = 'Preset:'
        end
        object lblSubE: TLabel
          Left = 12
          Top = 58
          Width = 50
          Height = 15
          Caption = 'E (GPa):'
        end
        object lblSubNu: TLabel
          Left = 200
          Top = 58
          Width = 22
          Height = 15
          Caption = 'nu:'
        end
        object lblSubSigmaY: TLabel
          Left = 12
          Top = 90
          Width = 78
          Height = 15
          Caption = 'sigma_y (GPa):'
        end
        object lblSubEt: TLabel
          Left = 12
          Top = 122
          Width = 58
          Height = 15
          Caption = 'E_t (GPa):'
        end
        object lblSubHardness: TLabel
          Left = 12
          Top = 154
          Width = 46
          Height = 15
          Caption = 'H (GPa):'
        end
        object cbSubPreset: TRzComboBox
          Left = 96
          Top = 22
          Width = 294
          Height = 23
          Style = csDropDownList
          TabOrder = 0
          OnChange = cbSubPresetChange
        end
        object edtSubE: TRzEdit
          Left = 96
          Top = 54
          Width = 96
          Height = 23
          TabOrder = 1
        end
        object edtSubNu: TRzEdit
          Left = 228
          Top = 54
          Width = 162
          Height = 23
          TabOrder = 2
        end
        object edtSubSigmaY: TRzEdit
          Left = 96
          Top = 86
          Width = 136
          Height = 23
          TabOrder = 3
        end
        object btnSubEstYield: TRzButton
          Left = 240
          Top = 85
          Width = 150
          Height = 25
          Caption = 'Est. sigma_y = H / 2.8'
          TabOrder = 4
          OnClick = btnSubEstYieldClick
        end
        object edtSubEt: TRzEdit
          Left = 96
          Top = 118
          Width = 294
          Height = 23
          TabOrder = 5
        end
        object edtSubHardness: TRzEdit
          Left = 96
          Top = 150
          Width = 136
          Height = 23
          TabOrder = 6
        end
      end
      object gbSolver: TRzGroupBox
        AlignWithMargins = True
        Left = 4
        Top = 692
        Width = 406
        Height = 164
        Align = alTop
        BorderOuter = fsFlatRounded
        Caption = 'Solver Settings'
        TabOrder = 4
        object lblEngine: TLabel
          Left = 12
          Top = 26
          Width = 46
          Height = 15
          Caption = 'Engine:'
        end
        object lblMeshDensity: TLabel
          Left = 12
          Top = 58
          Width = 76
          Height = 15
          Caption = 'Mesh Density:'
        end
        object lblElementType: TLabel
          Left = 12
          Top = 90
          Width = 76
          Height = 15
          Caption = 'FEM Element:'
        end
        object lblNRings: TLabel
          Left = 12
          Top = 122
          Width = 76
          Height = 15
          Caption = 'Elastic Rings:'
        end
        object cbEngine: TRzComboBox
          Left = 96
          Top = 22
          Width = 294
          Height = 23
          Style = csDropDownList
          TabOrder = 0
          Items.Strings = (
            'Both (Elastic + FEM)'
            'Layered Elastic (Engine 1)'
            'CalculiX FEM (Engine 2)')
          ItemIndex = 0
        end
        object cbMeshDensity: TRzComboBox
          Left = 96
          Top = 54
          Width = 294
          Height = 23
          Style = csDropDownList
          TabOrder = 1
          Items.Strings = (
            'Coarse'
            'Standard'
            'Fine')
          ItemIndex = 1
        end
        object cbElementType: TRzComboBox
          Left = 96
          Top = 86
          Width = 294
          Height = 23
          Style = csDropDownList
          TabOrder = 2
          Items.Strings = (
            'CAX4I'
            'CAX4'
            'CAX4R')
          ItemIndex = 1
        end
        object edtNRings: TRzEdit
          Left = 96
          Top = 118
          Width = 96
          Height = 23
          Text = '160'
          TabOrder = 3
        end
        object chkUnloading: TRzCheckBox
          Left = 204
          Top = 121
          Width = 186
          Height = 17
          Caption = 'Include Unloading Step (h_r)'
          TabOrder = 4
        end
      end
    end
    object pnlRight: TRzPanel
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 927
      Height = 750
      Align = alClient
      BorderOuter = fsFlatRounded
      TabOrder = 0
      object pnlTopResults: TRzPanel
        AlignWithMargins = True
        Left = 6
        Top = 6
        Width = 915
        Height = 210
        Align = alTop
        BorderOuter = fsFlatRounded
        TabOrder = 0
        object pnlBadge: TRzPanel
          AlignWithMargins = True
          Left = 5
          Top = 5
          Width = 905
          Height = 30
          Align = alTop
          BorderOuter = fsFlatRounded
          TabOrder = 0
          object lblYieldBadge: TLabel
            AlignWithMargins = True
            Left = 8
            Top = 4
            Width = 889
            Height = 22
            Align = alClient
            Caption = 'Yield Status: Ready (run solve to evaluate)'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsBold]
            Layout = tlCenter
            ParentFont = False
          end
        end
        object pgcTables: TRzPageControl
          AlignWithMargins = True
          Left = 5
          Top = 41
          Width = 905
          Height = 163
          ActivePage = tabSummary
          ActivePageDefault = tabSummary
          Align = alClient
          TabIndex = 0
          TabOrder = 1
          object tabSummary: TRzTabSheet
            Caption = 'Solver Summary'
            object grdSummary: TStringGrid
              AlignWithMargins = True
              Left = 4
              Top = 4
              Width = 895
              Height = 132
              Align = alClient
              ColCount = 8
              DefaultColWidth = 104
              DefaultRowHeight = 22
              FixedCols = 1
              RowCount = 5
              FixedRows = 1
              Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goColSizing]
              TabOrder = 0
            end
          end
          object tabInterfaces: TRzTabSheet
            Caption = 'Interface Discontinuities (z_k- / z_k+)'
            object grdInterfaces: TStringGrid
              AlignWithMargins = True
              Left = 4
              Top = 4
              Width = 895
              Height = 132
              Align = alClient
              ColCount = 10
              DefaultColWidth = 88
              DefaultRowHeight = 22
              FixedCols = 0
              RowCount = 2
              FixedRows = 1
              Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goColSizing]
              TabOrder = 0
            end
          end
        end
      end
      object pgcPlots: TRzPageControl
        AlignWithMargins = True
        Left = 6
        Top = 222
        Width = 915
        Height = 522
        ActivePage = tabPressure
        ActivePageDefault = tabPressure
        Align = alClient
        TabIndex = 0
        TabOrder = 1
        object tabPressure: TRzTabSheet
          Caption = 'Contact Pressure p(r)'
          object chtPressure: TChart
            AlignWithMargins = True
            Left = 4
            Top = 4
            Width = 905
            Height = 491
            Legend.Alignment = laTop
            Title.Text.Strings = (
              'Surface Contact Pressure Profile p(r)')
            BottomAxis.Title.Caption = 'Radius r (um)'
            LeftAxis.Title.Caption = 'Pressure p (GPa)'
            View3D = False
            Align = alClient
            TabOrder = 0
            DefaultCanvas = 'TGDIPlusCanvas'
            object srsPressHertzSub: TLineSeries
              SeriesColor = 9211020
              Title = 'Hertz Substrate'
              Brush.BackColor = clDefault
              LinePen.Color = 9211020
              LinePen.Width = 2
              Pointer.InflateMargins = True
              Pointer.Style = psRectangle
              XValues.Name = 'X'
              XValues.Order = loNone
              YValues.Name = 'Y'
              YValues.Order = loNone
            end
            object srsPressHertzFilm: TLineSeries
              SeriesColor = 3968568
              Title = 'Hertz Top Film'
              Brush.BackColor = clDefault
              LinePen.Color = 3968568
              LinePen.Width = 2
              Pointer.InflateMargins = True
              Pointer.Style = psRectangle
              XValues.Name = 'X'
              XValues.Order = loNone
              YValues.Name = 'Y'
              YValues.Order = loNone
            end
            object srsPressElastic: TLineSeries
              SeriesColor = 11826975
              Title = 'Elastic Layered'
              Brush.BackColor = clDefault
              LinePen.Color = 11826975
              LinePen.Width = 3
              Pointer.InflateMargins = True
              Pointer.Style = psRectangle
              XValues.Name = 'X'
              XValues.Order = loNone
              YValues.Name = 'Y'
              YValues.Order = loNone
            end
            object srsPressFem: TLineSeries
              SeriesColor = 2631638
              Title = 'CalculiX FEM'
              Brush.BackColor = clDefault
              LinePen.Color = 2631638
              LinePen.Width = 3
              Pointer.InflateMargins = True
              Pointer.Style = psRectangle
              XValues.Name = 'X'
              XValues.Order = loNone
              YValues.Name = 'Y'
              YValues.Order = loNone
            end
          end
        end
        object tabHeatmap: TRzTabSheet
          Caption = '2D Stress Heatmap'
          object pnlHeatmapBar: TRzPanel
            AlignWithMargins = True
            Left = 4
            Top = 4
            Width = 905
            Height = 38
            Align = alTop
            BorderOuter = fsFlatRounded
            TabOrder = 0
            object lblHmSolver: TLabel
              Left = 10
              Top = 11
              Width = 38
              Height = 15
              Caption = 'Solver:'
            end
            object lblHmField: TLabel
              Left = 220
              Top = 11
              Width = 32
              Height = 15
              Caption = 'Field:'
            end
            object cbHeatmapSolver: TRzComboBox
              Left = 54
              Top = 7
              Width = 154
              Height = 23
              Style = csDropDownList
              TabOrder = 0
              OnChange = cbHeatmapChange
              Items.Strings = (
                'Elastic Layered'
                'CalculiX FEM')
              ItemIndex = 0
            end
            object cbHeatmapField: TRzComboBox
              Left = 258
              Top = 7
              Width = 180
              Height = 23
              Style = csDropDownList
              TabOrder = 1
              OnChange = cbHeatmapChange
              Items.Strings = (
                'Von Mises (sigma_vM)'
                'Radial (sigma_rr)'
                'Shear (tau_rz)'
                'PEEQ'
                'Sliding (sigma_xx)')
              ItemIndex = 0
            end
            object btnSaveHeatmap: TRzButton
              Left = 450
              Top = 6
              Width = 118
              Height = 25
              Caption = 'Save Heatmap...'
              TabOrder = 2
              OnClick = btnSaveHeatmapClick
            end
          end
          object imgHeatmap: TImage
            AlignWithMargins = True
            Left = 4
            Top = 48
            Width = 905
            Height = 447
            Align = alClient
            Center = True
            Proportional = True
            Stretch = True
          end
        end
        object tabCenterline: TRzTabSheet
          Caption = 'Centerline Depth Profile'
          object chtCenterline: TChart
            AlignWithMargins = True
            Left = 4
            Top = 4
            Width = 905
            Height = 491
            Legend.Alignment = laTop
            Title.Text.Strings = (
              'Centerline Stress vs Depth (r = 0)')
            BottomAxis.Title.Caption = 'Stress (GPa)'
            LeftAxis.Inverted = True
            LeftAxis.Title.Caption = 'Depth z (um)'
            View3D = False
            Align = alClient
            TabOrder = 0
            DefaultCanvas = 'TGDIPlusCanvas'
            object srsClElVm: TLineSeries
              SeriesColor = 11826975
              Title = 'Elastic sigma_vM'
              Brush.BackColor = clDefault
              LinePen.Color = 11826975
              LinePen.Width = 2
              Pointer.InflateMargins = True
              Pointer.Style = psRectangle
              XValues.Name = 'X'
              XValues.Order = loNone
              YValues.Name = 'Y'
              YValues.Order = loNone
            end
            object srsClElRR: TLineSeries
              SeriesColor = 10506256
              Title = 'Elastic sigma_rr'
              Brush.BackColor = clDefault
              LinePen.Color = 10506256
              LinePen.Width = 2
              Pointer.InflateMargins = True
              Pointer.Style = psRectangle
              XValues.Name = 'X'
              XValues.Order = loNone
              YValues.Name = 'Y'
              YValues.Order = loNone
            end
            object srsClFemVm: TLineSeries
              SeriesColor = 2631638
              Title = 'FEM sigma_vM'
              Brush.BackColor = clDefault
              LinePen.Color = 2631638
              LinePen.Width = 2
              Pointer.InflateMargins = True
              Pointer.Style = psRectangle
              XValues.Name = 'X'
              XValues.Order = loNone
              YValues.Name = 'Y'
              YValues.Order = loNone
            end
            object srsClFemRR: TLineSeries
              SeriesColor = 1332552
              Title = 'FEM sigma_rr'
              Brush.BackColor = clDefault
              LinePen.Color = 1332552
              LinePen.Width = 2
              Pointer.InflateMargins = True
              Pointer.Style = psRectangle
              XValues.Name = 'X'
              XValues.Order = loNone
              YValues.Name = 'Y'
              YValues.Order = loNone
            end
          end
        end
        object tabSweep: TRzTabSheet
          Caption = 'Load Sweep'
          object pnlSweepBar: TRzPanel
            AlignWithMargins = True
            Left = 4
            Top = 4
            Width = 905
            Height = 38
            Align = alTop
            BorderOuter = fsFlatRounded
            TabOrder = 0
            object lblSweepLoads: TLabel
              Left = 10
              Top = 11
              Width = 74
              Height = 15
              Caption = 'Loads (mN):'
            end
            object edtSweepLoads: TRzEdit
              Left = 90
              Top = 7
              Width = 260
              Height = 23
              Text = '500, 1000, 2000, 5000, 10000'
              TabOrder = 0
            end
            object btnRunSweep: TRzButton
              Left = 362
              Top = 6
              Width = 104
              Height = 25
              Caption = 'Run Sweep'
              TabOrder = 1
              OnClick = btnSweepClick
            end
          end
          object imgSweep: TImage
            AlignWithMargins = True
            Left = 4
            Top = 48
            Width = 905
            Height = 447
            Align = alClient
            Center = True
            Proportional = True
            Stretch = True
          end
        end
        object tabMesh: TRzTabSheet
          Caption = 'FEM Mesh Preview'
          object pnlMeshBar: TRzPanel
            AlignWithMargins = True
            Left = 4
            Top = 4
            Width = 905
            Height = 38
            Align = alTop
            BorderOuter = fsFlatRounded
            TabOrder = 0
            object chkMeshZoom: TRzCheckBox
              Left = 12
              Top = 10
              Width = 176
              Height = 17
              Caption = 'Zoom to Contact Zone'
              Checked = True
              State = cbChecked
              TabOrder = 0
              OnClick = chkMeshZoomClick
            end
            object btnPreviewMesh: TRzButton
              Left = 200
              Top = 6
              Width = 118
              Height = 25
              Caption = 'Regenerate Mesh'
              TabOrder = 1
              OnClick = btnPreviewMeshClick
            end
          end
          object imgMesh: TImage
            AlignWithMargins = True
            Left = 4
            Top = 48
            Width = 905
            Height = 447
            Align = alClient
            Center = True
            Proportional = True
            Stretch = True
          end
        end
        object tabLog: TRzTabSheet
          Caption = 'Solver Log'
          object memLog: TRzMemo
            AlignWithMargins = True
            Left = 4
            Top = 4
            Width = 905
            Height = 491
            Align = alClient
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -12
            Font.Name = 'Consolas'
            Font.Style = []
            ParentFont = False
            ReadOnly = True
            ScrollBars = ssBoth
            TabOrder = 0
            WordWrap = False
          end
        end
      end
    end
  end
  object MainMenu1: TMainMenu
    Left = 1000
    Top = 12
    object mniFile: TMenuItem
      Caption = '&File'
      object mniOpenCase: TMenuItem
        Caption = '&Open Case JSON...'
        OnClick = btnOpenClick
      end
      object mniSaveCase: TMenuItem
        Caption = '&Save Case JSON...'
        OnClick = btnSaveClick
      end
      object mniExamples: TMenuItem
        Caption = 'E&xamples'
        object mniExTinSteel: TMenuItem
          Caption = 'TiN 2 um on 304 Steel (5 N)'
          OnClick = mniExTinSteelClick
        end
        object mniExDlcGlass: TMenuItem
          Caption = 'DLC 1.5 um on Glass Sliding mu=0.20 (2 N)'
          OnClick = mniExDlcGlassClick
        end
        object mniExSicPmma: TMenuItem
          Caption = 'SiC 1 um on PMMA (200 mN)'
          OnClick = mniExSicPmmaClick
        end
      end
      object mniSepFile1: TMenuItem
        Caption = '-'
      end
      object mniExportData: TMenuItem
        Caption = 'Export Results (&CSV + JSON)...'
        OnClick = btnExportDataClick
      end
      object mniExportPlots: TMenuItem
        Caption = 'Export &Plots (PNG + PDF)...'
        OnClick = btnExportPlotsClick
      end
      object mniSepFile2: TMenuItem
        Caption = '-'
      end
      object mniExit: TMenuItem
        Caption = 'E&xit'
        OnClick = mniExitClick
      end
    end
    object mniSolve: TMenuItem
      Caption = '&Solve'
      object mniRunSolve: TMenuItem
        Caption = '&Run Solve'
        ShortCut = 116
        OnClick = btnSolveClick
      end
      object mniCancel: TMenuItem
        Caption = '&Cancel'
        Enabled = False
        OnClick = btnCancelClick
      end
      object mniRunSweep: TMenuItem
        Caption = 'Run Load &Sweep'
        OnClick = btnSweepClick
      end
      object mniPreviewMesh: TMenuItem
        Caption = 'Preview FEM &Mesh'
        OnClick = btnPreviewMeshClick
      end
      object mniSetupCcx: TMenuItem
        Caption = 'Setup / Verify Calculi&X...'
        OnClick = btnSetupCcxClick
      end
    end
    object mniLibrary: TMenuItem
      Caption = '&Library'
      object mniManageMaterials: TMenuItem
        Caption = '&Material Presets Manager...'
        OnClick = btnMaterialsClick
      end
    end
    object mniHelp: TMenuItem
      Caption = '&Help'
      object mniUserManual: TMenuItem
        Caption = '&User Manual'
        ShortCut = 112
        OnClick = btnHelpClick
      end
      object mniSepHelp: TMenuItem
        Caption = '-'
      end
      object mniAbout: TMenuItem
        Caption = '&About TriboContact'
        OnClick = mniAboutClick
      end
    end
  end
  object dlgOpenCase: TOpenDialog
    DefaultExt = 'json'
    Filter = 'TriboContact Case JSON (*.json)|*.json|All Files (*.*)|*.*'
    Options = [ofHideReadOnly, ofFileMustExist, ofEnableSizing]
    Left = 1044
    Top = 12
  end
  object dlgSaveCase: TSaveDialog
    DefaultExt = 'json'
    Filter = 'TriboContact Case JSON (*.json)|*.json|All Files (*.*)|*.*'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Left = 1084
    Top = 12
  end
  object dlgSelectDir: TFileOpenDialog
    FavoriteLinks = <>
    FileTypes = <>
    Options = [fdoPickFolders, fdoPathMustExist]
    Title = 'Select Output Folder'
    Left = 1124
    Top = 12
  end
  object dlgSaveImage: TSaveDialog
    DefaultExt = 'png'
    Filter = 'PNG Image (*.png)|*.png|PDF Document (*.pdf)|*.pdf'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Left = 1164
    Top = 12
  end
end
