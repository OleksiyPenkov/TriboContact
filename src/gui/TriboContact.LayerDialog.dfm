object frmLayerDialog: TfrmLayerDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Coating Layer Editor'
  ClientHeight = 362
  ClientWidth = 446
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  TextHeight = 15
  object pnlMain: TRzPanel
    AlignWithMargins = True
    Left = 6
    Top = 6
    Width = 434
    Height = 300
    Align = alClient
    BorderOuter = fsFlatRounded
    TabOrder = 0
    object lblPreset: TLabel
      Left = 16
      Top = 18
      Width = 90
      Height = 15
      Caption = 'Coating Preset:'
    end
    object lblName: TLabel
      Left = 16
      Top = 52
      Width = 90
      Height = 15
      Caption = 'Material Name:'
    end
    object lblThickness: TLabel
      Left = 16
      Top = 86
      Width = 90
      Height = 15
      Caption = 'Thickness:'
    end
    object lblE: TLabel
      Left = 16
      Top = 120
      Width = 90
      Height = 15
      Caption = 'Modulus E (GPa):'
    end
    object lblNu: TLabel
      Left = 16
      Top = 154
      Width = 90
      Height = 15
      Caption = 'Poisson nu:'
    end
    object lblSigmaY: TLabel
      Left = 16
      Top = 188
      Width = 96
      Height = 15
      Caption = 'Yield sigma_y (GPa):'
    end
    object lblEt: TLabel
      Left = 16
      Top = 222
      Width = 96
      Height = 15
      Caption = 'Tangent E_t (GPa):'
    end
    object lblHardness: TLabel
      Left = 16
      Top = 256
      Width = 90
      Height = 15
      Caption = 'Hardness H (GPa):'
    end
    object cbPreset: TRzComboBox
      Left = 132
      Top = 14
      Width = 282
      Height = 23
      Style = csDropDownList
      TabOrder = 0
      OnChange = cbPresetChange
    end
    object edtName: TRzEdit
      Left = 132
      Top = 48
      Width = 282
      Height = 23
      TabOrder = 1
    end
    object edtThickness: TRzEdit
      Left = 132
      Top = 82
      Width = 190
      Height = 23
      TabOrder = 2
    end
    object cbThickUnit: TRzComboBox
      Left = 330
      Top = 82
      Width = 84
      Height = 23
      Style = csDropDownList
      TabOrder = 3
      Items.Strings = (
        'um'
        'nm')
      ItemIndex = 0
    end
    object edtE: TRzEdit
      Left = 132
      Top = 116
      Width = 282
      Height = 23
      TabOrder = 4
    end
    object edtNu: TRzEdit
      Left = 132
      Top = 150
      Width = 282
      Height = 23
      TabOrder = 5
    end
    object edtSigmaY: TRzEdit
      Left = 132
      Top = 184
      Width = 122
      Height = 23
      TabOrder = 6
    end
    object btnEstYield: TRzButton
      Left = 262
      Top = 183
      Width = 152
      Height = 25
      Caption = 'Estimate sigma_y = H / 2.8'
      TabOrder = 7
      OnClick = btnEstYieldClick
    end
    object edtEt: TRzEdit
      Left = 132
      Top = 218
      Width = 282
      Height = 23
      TabOrder = 8
    end
    object edtHardness: TRzEdit
      Left = 132
      Top = 252
      Width = 122
      Height = 23
      TabOrder = 9
    end
    object btnSavePreset: TRzButton
      Left = 262
      Top = 251
      Width = 152
      Height = 25
      Caption = 'Save Custom Preset'
      TabOrder = 10
      OnClick = btnSavePresetClick
    end
  end
  object pnlButtons: TRzPanel
    AlignWithMargins = True
    Left = 6
    Top = 312
    Width = 434
    Height = 44
    Align = alBottom
    BorderOuter = fsFlatRounded
    TabOrder = 1
    object btnOK: TRzButton
      Left = 248
      Top = 9
      Width = 84
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = btnOKClick
    end
    object btnCancel: TRzButton
      Left = 340
      Top = 9
      Width = 84
      Height = 26
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
end
