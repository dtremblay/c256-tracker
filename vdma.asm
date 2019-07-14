SETUP_VDMA_FOR_TESTING_1D
                setas
                LDA #$01 ; Start Transfer
                STA @lVDMA_CONTROL_REG

                LDA #$FE
                STA @lVDMA_SIZE_L
                LDA #$9F
                STA @lVDMA_SIZE_M
                LDA #$00
                STA @lVDMA_SIZE_H

                LDA #$64
                STA @lVDMA_DST_ADDY_L
                LDA #$84
                STA @lVDMA_DST_ADDY_M
                LDA #$03
                STA @lVDMA_DST_ADDY_H

                LDA #$55
                STA @lVDMA_BYTE_2_WRITE

                LDA #$85 ; Start Transfer
                STA @lVDMA_CONTROL_REG
                LDA @lVDMA_STATUS_REG
                RTS

SETUP_VDMA_FOR_TESTING_2D
                setas

VDMA_WAIT_TF
; Wait for the Previous Transfer to be Finished
                LDA @lVDMA_STATUS_REG
                AND #VDMA_STAT_VDMA_IPS
                CMP #VDMA_STAT_VDMA_IPS
                BEQ VDMA_WAIT_TF

                LDA #$01 ; Start Transfer
                STA @lVDMA_CONTROL_REG

                LDA #200
                STA @lVDMA_X_SIZE_L
                LDA #00
                STA @lVDMA_X_SIZE_H

                LDA #64
                STA @lVDMA_Y_SIZE_L
                LDA #00
                STA @lVDMA_Y_SIZE_H

                LDA #$60
                STA @lVDMA_DST_ADDY_L
                LDA #$90
                STA @lVDMA_DST_ADDY_M
                LDA #$01
                STA @lVDMA_DST_ADDY_H

                LDA #$80
                STA @lVDMA_DST_STRIDE_L
                LDA #$02
                STA @lVDMA_DST_STRIDE_H

                LDA #$F9
                STA @lVDMA_BYTE_2_WRITE

                LDA #$87 ; Start Transfer
                STA @lVDMA_CONTROL_REG
                LDA @lVDMA_STATUS_REG
                RTS