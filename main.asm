;*******************************************************************
;* This stationery serves as the framework for a user application. *
;* For a more comprehensive program that demonstrates the more     *
;* advanced functionality of this processor, please see the        *
;* demonstration applications, located in the examples             *
;* subdirectory of the "Freescale CodeWarrior for HC08" program    *
;* directory.                                                      *
;*******************************************************************

; Include derivative-specific definitions
            INCLUDE 'derivative.inc'
            
;
; export symbols
;
            XDEF _Startup
            ABSENTRY _Startup

;
; variable/data section
;

MASKMUL      EQU %01111111
MASKSIGN     EQU %10000000
MASKOP		 EQU %00000011
ASCII		 EQU %00000011	



            ORG    Z_RAMStart       	; Variables in page zero 
BCD: 		 DS.B   6					; Array of directions for numbers to show
BCD_OK:		 DS.B	5
Op1:         DS.B   1					; Sign operand one
Op2:         DS.B   1					; Sign operand two
Sign:		 DS.B   1					; Result sign in the multiplication and dision operations
Count:		 DS.B	1					; Control for decimal division
Counter:	 DS.B	1					; Control zero division
Res:         DS.B   2


			ORG		RAMStart
DECI:		 DS.B 	5					; Array for the 
Control:     DS.B   1
Counter_BDC: DS.B   1

Op1T:        DS.B   1
Op2T:        DS.B   1
TEST:		 DS.B	1
CONTS:		 DS.B	1


;
; code section
;
            ORG    ROMStart
            

_Startup:
            LDHX   #RAMEnd+1        ; initialize the stack pointer
            TXS
            LDA #$20
            STA SOPT1
; Intialize the common register            
            CLRX
            CLRH
            CLR Count
			CLR Counter
			CLR Res
			CLR Res+1
            
; Declare Ports
;A      -> Input
;B      -> Output
;C(1:0) -> Input
;D      -> Input
; LCD ENABLE -> PTA4   LCD RS -> PTA3 
            LDA #$01
            STA PTAPE
            MOV #$18,PTADD 
            MOV #$00,PTAD 
                       
            MOV #$FF,PTBDD
            LDA #$FF
            STA PTBDS
            MOV #$00, PTBD
            
            MOV #$00,PTFDD
            LDA #$00
            STA PTFPE
            
            MOV #$FC, PTCDD
            LDA #$0F
            STA PTCPE
    		MOV #$00, PTCD

            LDA #20
			JSR Delay
			
            JSR LCD_Init

            
Inicio:
	
	
	
	Enter_Op1:	BRCLR 0, PTAD, Capture1
				BRA Enter_Op1
	Capture1:	LDA PTFD
				STA Op1
				JSR SHOW_NUM
				JSR Debounce
	Select_Op:	BRCLR 0, PTAD, Calc
				BRA Select_Op
	Calc:		LDA PTFD
				AND #MASKOP
				STA Control
				JSR Debounce
				LDA Control
				CBEQA #0, ADDITION
				CBEQA #1, SUBTRACTION
				CBEQA #2, MULTIPLY
				CBEQA #3, DTEMP
											
	Enter_Op2:  BRCLR 0, PTAD, Capture2
				BRA Enter_Op2
	Capture2:   LDA PTFD
				STA Op2
				JSR SHOW_NUM
				JSR Debounce
				RTS

	DTEMP:		JMP DIVISION	
	
ADDITION:		
				LDA #$2B
				JSR LCD_DATA
				JSR Enter_Op2
RES_JMP:		LDA Op1
				ADD Op2
				BLT Overflow
				STA BCD
				STA Res+1
				MOV #0, Sign
				JSR BDConverter8
				JMP Here
	Overflow:	BEQ Max_Over
				NEGA
				STA BCD
				STA Res+1
				MOV #1, Sign
				JSR BDConverter8
				JMP Here
	Max_Over:	STA BCD+1
				LDX #1
				STX BCD
				STA Res+1
				STX Res
				CLRA
				JSR BDConverter16
				MOV #1, Sign  		
				JMP Here
SUBTRACTION:
		
		LDA #$2D
		JSR LCD_DATA
		JSR Enter_Op2
		LDA Op2
		NEGA
		STA Op2
		BRA RES_JMP
	
MULTIPLY:
			LDA #$78
			JSR LCD_DATA
			JSR Enter_Op2
			LDA Op1
			BRCLR 7,Op1, PositiveN1
			NEGA
PositiveN1:	TAX
			LDA Op2
			BRCLR 7,Op2, PositiveN2
			NEGA
PositiveN2:	MUL		
			STA BCD+1
			STX BCD
			STA Res+1
			STX Res
			LDA Op1
			AND #MASKSIGN
			STA Sign
			LDA Op2
			AND #MASKSIGN
			EOR Sign
			BNE SignNeg
			LDA #0
			STA Sign
			BRA ADAPTBCD
SignNeg:	LDA #1
			STA Sign
ADAPTBCD:	JSR BDConverter16
			JMP Here

DIVISION:		LDA #$2F
				JSR LCD_DATA
				JSR Enter_Op2
				LDA Op2
				STA Op2T
				BRCLR 7,Op2, PositiveDN1
				NEGA
				STA Op2
PositiveDN1:	TAX
				LDA Op1
				STA Op1T
				BRCLR 7,Op1, PositiveDN2
				NEGA
				STA Op2
PositiveDN2:	
				CMP Op2
				BHS AKAS
				LDX #0
				PSHX
				BRA YAPI 
AKAS:			DIV
				PSHA
				PSHH
				PULA
				CLRH
				CBEQA #0, FinishD
				
YAPI:			LDX Count
				CBEQX #4, FinishD
				LDX #10
				MUL
				INC Counter
				PSHA
				LDA #1
				CMP Counter
				BHS CeroPoint
				PULH
				LDA #0
				PSHA
				PSHH
				CLRH
				INC Count
				
CeroPoint:		PSHX
				PULH
				PULA
				CMP Op2
				BLO YAPI
				LDX Op2
				DIV
				MOV #0, Counter
				INC Count
				PSHA
				PSHH
				PULA
				CLRH
				CBEQA #0, FinishD
				BRA YAPI
								
FinishD:		CLRX
				INC Count
LOOPDIV:		
				PULA				
				CMP #10
				BLO Siga_2
				JSR BDConverter8
				DBNZ Count, LOOPDIV
				BRA SignCorrect		
Siga_2:			 
				ADD #'0'
				STA DECI,X
				INCX
				DBNZ Count, LOOPDIV
SignCorrect:	LDA Op1T
				AND #MASKSIGN
				STA Sign
				LDA Op2T
				AND #MASKSIGN
				EOR Sign
				BNE SignNeg2
				LDA #0
				STA Sign
				BRA Here
SignNeg2:		LDA #1
				STA Sign
			
										
Here:	
		
	LDA Sign
	CMP #0
	BEQ Listos
	ADD #$2C
	JSR LCD_DATA
	
Listos:	
		LDA #$3D
		JSR LCD_DATA
		JSR SHOW_RESULT
					
			


Final:	BRA Final




		

;**************************************************************
;*                   Subroutines                              *
;**************************************************************
; Subroutine for Delay in microseconds
; Configure the register A to control the time in microsecond for a clock of 8MHz
; Period of clock is 125 ns and cycle repeat 9 times of 890 (125*10^-9)*9*(890) = 1 ms
Delay:
		PSHX
Pass:	LDHX #890                ; 3 cycles
Loop:	AIX #-1						; 2 cycles
		CPHX #0						; 2 cycles	
		BHI Loop					; 3 cycles
		DECA						; 1 cycle
		BEQ Fin						; 3 cycles
		BRA Pass					; 3 cycles
Fin:    
		PULX
		RTS

;****************************************************************
;*                LCD CONTROLLER DRIVER (12*2)                  *
*****************************************************************

LCD_Init:	LDA #$30		;Activation command 1
			BSR LCD_CMD
			LDA #10
			JSR Delay			
			LDA #$30		;Activation command 2
			BSR LCD_CMD
			LDA #1
			JSR Delay		
			LDA #$30		;Activation command 3
			BSR LCD_CMD
			LDA #1
			JSR Delay
			LDA #$01		;Clear display
			BSR LCD_CMD
			LDA #1
			JSR Delay	
			LDA #$06		; Configuration
			BSR LCD_CMD
			LDA #1
			JSR Delay	
			LDA #$0C		; Configuration
			BSR LCD_CMD
			LDA #1
			JSR Delay
			LDA #$38		; Configuration
			BSR LCD_CMD
			LDA #1
			JSR Delay		
			RTS
;Send command to LCD in register A			
LCD_CMD:	MOV #$00, PTAD
			STA PTBD
			MOV #$10, PTAD
			LDA #2
			BSR Delay
			MOV #$00, PTAD
			RTS
;Send data to LCD in register A				
LCD_DATA:	MOV #$08, PTAD
			STA PTBD
			MOV #$18, PTAD
			LDA #2
			JSR Delay
			MOV #$08, PTAD
			RTS			
;****************************************************************
;*                Debounce software filter                      *
*****************************************************************
Debounce:	BSR Delay
			BRCLR 0, PTAD,Debounce
			RTS	
		
;****************************************************************
;*						Show LCD number							*
;****************************************************************

SHOW_RESULT:	LDA Res

				CBEQA #0,NORMAL_MODE
				LDHX #10000
				CPHX Res
				BLS SHOW_10000
				LDHX #1000
				CPHX Res
				BLS SHOW_1000
				BRA SHOW_256
				
SHOW_10000:		CLRX
				CLRH
Loop_10000:		LDA BCD,X
				JSR LCD_DATA
				INCX
				CBEQX #5, End_ShowRE				
				BRA Loop_10000
SHOW_1000:		CLRX
				CLRH
Loop_1000:		LDA BCD+1,X
				JSR LCD_DATA
				INCX
				CBEQX #4, End_ShowRE
				BRA Loop_1000

SHOW_256:		CLRX
				CLRH
Loop_100:		LDA BCD+2,X
				JSR LCD_DATA
				INCX
				CBEQX #3, End_ShowRE
				BRA Loop_100
							
NORMAL_MODE:	LDA Res+1
				CLRX
				CLRH
				CMP #100
				BHS SHOWRE_100
				CMP #10
				BHS SHOWRE_10
				LDA BCD+3
				JSR LCD_DATA
				BRA End_ShowRE			
SHOWRE_100:		LDA BCD+2,X
				JSR LCD_DATA
				INCX
				CBEQX #3, End_ShowRE
				BRA SHOWRE_100	
SHOWRE_10:		LDA BCD+3,X
				JSR LCD_DATA
				INCX
				CBEQX #2, End_ShowRE
				BRA SHOWRE_10
				
End_ShowRE:		RTS					



;****************************************************************
;*						Change the number						*
;****************************************************************

SHOW_NUM:	CMP #0
			BGE Revision
			NEGA
			PSHA
			LDA #$2D
			JSR LCD_DATA
			PULA
Revision:	JSR BDConverter8
			CLRX
			CLRH
			CMP #100
			BHS SHOW_100
			CMP #10
			BHS SHOW_10
			LDA BCD+3
			JSR LCD_DATA
			BRA End_Show			
SHOW_100:	LDA BCD+1,X
			JSR LCD_DATA
			INCX
			CBEQX #3, End_Show
			BRA SHOW_100	
SHOW_10:	LDA BCD+2,X
			JSR LCD_DATA
			INCX
			CBEQX #2, End_Show
			BRA SHOW_10
			 

End_Show:	RTS			
	
;****************************************************************
;*                  Multiply helper (Sign)                      *
;****************************************************************			
ChangeSign:	  LDA #%10000000
			  ORA Res+1
			  STA Res+1
			  RTS
;****************************************************************
;*                 BCD converter 8 Bits  (Signed)               *
;****************************************************************
BDConverter8:
				PSHA
				PSHX
				PSHH
				LDX #100
				DIV
				ADD #'0'
				STA BCD+1
				PSHH
				CLRH
				PULA
				LDX #10
				DIV
				ADD #'0'
				STA BCD+2
				PSHH
				PULA
				ADD #'0'
				STA BCD+3
				PULH
				PULX
				PULA
				RTS
		
;****************************************************************
;*                BCD converter 16 Bits  (Signed)               *
;****************************************************************
BDConverter16:
		  LDX    #4             ; Number of divisions required
          STX    BCD+5
          LDX    #10            ; Divisor
CNV1:     BSR    DIVIDE
          PSHH                  ; Store remainder to stack
          DBNZ   BCD+5,CNV1     ; Loop for next digit
 
          ADD    #'0'           ; Convert to numeric ASCII
          STA    BCD            ; MS digit
          CLRX                  ; Buffer index
          CLRH
CNV2:     PULA                  ; Get value from stack
          ADD    #'0'           ; Convert to numeric ASCII
          STA    BCD+1,X
          INCX
          CPX    #4             ; Test for maximum digits
          BLO    CNV2           ; Loop if not
          RTS
 
DIVIDE:   CLRH
          LDA    BCD
          DIV
          STA    BCD
          LDA    BCD+1
          DIV
          STA    BCD+1
          RTS


;**************************************************************
;* 				Messages  - Application messages              *
;**************************************************************

			
WELCOME_M:	DC.B	$57		;W
			DC.B	$45		;E
			DC.B	$4C		;L
			DC.B	$43		;C
			DC.B	$4F		;O
			DC.B	$4D		;M
			DC.B	$45		;E
			
CALCU_M:	DC.B	$54
			DC.B	$4F
			DC.B	$20
			DC.B	$43
			DC.B	$41
			DC.B	$4C
			DC.B	$43
			DC.B	$55
			DC.B	$4C
			DC.B	$55
			DC.B	$4C
			DC.B	$41
			DC.B	$54
			DC.B	$4F
			DC.B	$52
				




;**************************************************************
;* spurious - Spurious Interrupt Service Routine.             *
;*             (unwanted interrupt)                           *
;**************************************************************

spurious:				; placed here so that security value
			NOP			; does not change all the time.
			RTI

;**************************************************************
;*                 Interrupt Vectors                          *
;**************************************************************

            ORG	$FFFA

			DC.W  spurious			;
			DC.W  spurious			; SWI
			DC.W  _Startup			; Reset
