object frmMaterialDialog: TfrmMaterialDialog
  Left = 0
  Top = 0
  Caption = 'Material Presets Manager'
  ClientHeight = 480
  ClientWidth = 840
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  TextHeight = 15
  object pnlFilter: TRzPanel
    AlignWithMargins = True
    Left = 6
    Top = 6
    Width = 828
    Height = 42
    Align = alTop
    BorderOuter = fsFlatRounded
    TabOrder = 0
    object lblCategoryFilter: TLabel
      Left = 14
      Top = 13
      Width = 52
      Height = 15
      Caption = 'Category:'
    end
    object cbCategoryFilter: TRzComboBox
      Left = 74
      Top = 9
      Width = 170
      Height = 23
      Style = csDropDownList
      TabOrder = 0
      OnChange = cbCategoryFilterChange
      Items.Strings = (
        'All'
        'Ball'
        'Coating'
        'Substrate')
      ItemIndex = 0
    end
  end
  object pnlCenter: TRzPanel
    AlignWithMargins = True
    Left = 6
    Top = 54
    Width = 828
    Height = 370
    Align = alClient
    BorderOuter = fsFlatRounded
    TabOrder = 1
    object lvMaterials: TListView
      AlignWithMargins = True
      Left = 6
      Top = 6
      Width = 430
      Height = 358
      Align = alLeft
      Columns = <
        item
          Caption = 'Name'
          Width = 115
        end
        item
          Caption = 'Category'
          Width = 75
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
          Width = 60
        end
        item
          Caption = 'H (GPa)'
          Width = 55
        end>
      GridLines = True
      HideSelection = False
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnSelectItem = lvMaterialsSelectItem
    end
    object gbEditor: TRzGroupBox
      AlignWithMargins = True
      Left = 442
      Top = 6
      Width = 380
      Height = 358
      Align = alClient
      BorderOuter = fsFlatRounded
      Caption = 'Material Properties'
      TabOrder = 1
      object lblName: TLabel
        Left = 14
        Top = 28
        Width = 90
        Height = 15
        Caption = 'Name:'
      end
      object lblCategory: TLabel
        Left = 14
        Top = 62
        Width = 90
        Height = 15
        Caption = 'Category:'
      end
      object lblE: TLabel
        Left = 14
        Top = 96
        Width = 96
        Height = 15
        Caption = 'Modulus E (GPa):'
      end
      object lblNu: TLabel
        Left = 14
        Top = 130
        Width = 90
        Height = 15
        Caption = 'Poisson nu:'
      end
      object lblSigmaY: TLabel
        Left = 14
        Top = 164
        Width = 98
        Height = 15
        Caption = 'Yield sigma_y (GPa):'
      end
      object lblEt: TLabel
        Left = 14
        Top = 198
        Width = 98
        Height = 15
        Caption = 'Tangent E_t (GPa):'
      end
      object lblHardness: TLabel
        Left = 14
        Top = 232
        Width = 92
        Height = 15
        Caption = 'Hardness H (GPa):'
      end
      object lblNotes: TLabel
        Left = 14
        Top = 266
        Width = 90
        Height = 15
        Caption = 'Notes:'
      end
      object edtName: TRzEdit
        Left = 124
        Top = 24
        Width = 238
        Height = 23
        TabOrder = 0
      end
      object cbCategory: TRzComboBox
        Left = 124
        Top = 58
        Width = 238
        Height = 23
        Style = csDropDownList
        TabOrder = 1
        Items.Strings = (
          'Ball'
          'Coating'
          'Substrate')
        ItemIndex = 1
      end
      object edtE: TRzEdit
        Left = 124
        Top = 92
        Width = 238
        Height = 23
        TabOrder = 2
      end
      object edtNu: TRzEdit
        Left = 124
        Top = 126
        Width = 238
        Height = 23
        TabOrder = 3
      end
      object edtSigmaY: TRzEdit
        Left = 124
        Top = 160
        Width = 108
        Height = 23
        TabOrder = 4
      end
      object btnEstYield: TRzButton
        Left = 238
        Top = 159
        Width = 124
        Height = 25
        Caption = 'Est. sigma_y = H/2.8'
        TabOrder = 5
        OnClick = btnEstYieldClick
      end
      object edtEt: TRzEdit
        Left = 124
        Top = 194
        Width = 238
        Height = 23
        TabOrder = 6
      end
      object edtHardness: TRzEdit
        Left = 124
        Top = 228
        Width = 238
        Height = 23
        TabOrder = 7
      end
      object edtNotes: TRzEdit
        Left = 124
        Top = 262
        Width = 238
        Height = 23
        TabOrder = 8
      end
      object btnSaveCustom: TRzButton
        Left = 124
        Top = 306
        Width = 238
        Height = 28
        Caption = 'Save as Custom User Preset'
        TabOrder = 9
        OnClick = btnSaveCustomClick
      end
    end
  end
  object pnlBottom: TRzPanel
    AlignWithMargins = True
    Left = 6
    Top = 430
    Width = 828
    Height = 44
    Align = alBottom
    BorderOuter = fsFlatRounded
    TabOrder = 2
    object lblUserPath: TLabel
      AlignWithMargins = True
      Left = 10
      Top = 6
      Width = 716
      Height = 32
      Align = alClient
      AutoSize = False
      Caption = 'Custom presets file:'
      Layout = tlCenter
    end
    object btnClose: TRzButton
      AlignWithMargins = True
      Left = 732
      Top = 8
      Width = 88
      Height = 28
      Align = alRight
      Cancel = True
      Caption = 'Close'
      ModalResult = 1
      TabOrder = 0
    end
  end
end
