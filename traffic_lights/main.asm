;
; traffic_lights.asm
;
; Created: 27/02/2019 13:30:00
; Authors : Allan Amaro, �caro Gabriel, Ricardo Fragoso, Wagner Williams.
;
; Description: Projeto de 4 sem�foros sincronizados, simulando o funcionamento dos sem�foros localizados no cruzamento da Av. �lvaro Otac�lio com a R. Prof. Sandoval Arroxelas, na cidade de Macei�/AL.
;
; Notice: Os sem�foros foram observados no dia 10/02/2019, �s 23h30.
;

.equ UBRRvalue = 103	; baudrate = 9600

.def temp = r16	; registrador tempor�rio para opera��es gerais.
.def div = r0	; registrador para decimal Tx
.def aux = r1	; registrador auxiliar para opera��es de substitui��o.
.def display_1 = r17	; guarda o estado atual do Display 1.
.def display_2 = r18	; guarda o estado atual do Display 2.
.def display_id = r19	; guarda o id do display ativado atualmente (1: Display 1 / 2: Display 2).
.def time_counter = r20	; conta passagem dos segundos para controle de estado dos sem�foros.
.def state_counter = r21	; representa o offset do estado atual no espa�o de mem�ria onde os estados est�o guardados.
.def traffic_light_counter_1 = r22	; conta a dura��o restante para mudan�a de estado no sem�foro 1.
.def traffic_light_counter_2 = r23	; conta a dura��o restante para mudan�a de estado no sem�foro 2.
.def traffic_light_counter_3 = r24	; conta a dura��o restante para mudan�a de estado no sem�foro 3.
.def traffic_light_counter_4 = r25	; conta a dura��o restante para mudan�a de estado no sem�foro 4.

.dseg
b_states: .byte 8	; estados dos sem�foros relativos a porta B.
d_states: .byte 8	; estados dos sem�foros relativos a porta D.
states_durations: .byte 8	; dura��o de cada tupla de estado relacionado nas labels acima.
traffic_light_1: .byte 4  ; guarda a dura��o de cada estado (3 primeiros bytes) e qual o estado atual (�ltimo byte) do Sem�foro 1: Entrando na Sandoval.
traffic_light_2: .byte 4  ; guarda a dura��o de cada estado (3 primeiros bytes) e qual o estado atual (�ltimo byte) do Sem�foro 2: Sentido Stella Maris.
traffic_light_3: .byte 4  ; guarda a dura��o de cada estado (3 primeiros bytes) e qual o estado atual (�ltimo byte) do Sem�foro 3: Saindo da Sandoval.
traffic_light_4: .byte 4  ; guarda a dura��o de cada estado (3 primeiros bytes) e qual o estado atual (�ltimo byte) do Sem�foro 4: Sentido Ponta Verde.

.cseg
jmp setup
.org OC1Aaddr
jmp OC1A_Interrupt
.org OC0Aaddr
jmp OC0A_Interrupt

; Esta fun��o controla o valor exibido em cada display, bem como implementa suas opera��es (decremento e reset).
; Usada para mostrar a contagem regressiva da dura��o do estado atual do Sem�foro 4: Sentido Ponta Verde.
display_control:
	; Pega valores atuais dos displays (�ltimos 4 bits)
	ldi temp, 0b1111
	and display_1, temp
	and display_2, temp
	
	; Verifica as condi��es para decremento e tratamento de zero
	cpi display_1, 0
	breq decrement_display_2
	cpi display_2, 0
	breq decrement_display_1

	; Decrementa Display 2 e verifica se Display 1 � zero. Caso seja, verifica Display 2 na chamada do 'breq'.
	decrement_display_2:
		dec display_2
		cpi display_1, 0
		breq are_both_zero
		jmp activate_displays

	; Caso em que Display 2 chega em zero e Display 1 � diferente de zero. Decrementa Display 1 e reseta Display 2 com 9.
	decrement_display_1:
		dec display_1
		ldi display_2, 9
		jmp activate_displays
	
	; Se ambos os displays forem zero, muda estado dos displays (contagem do pr�ximo estado).
	are_both_zero:
		cpi display_2, 0
		brne activate_displays

	; Verifica qual o estado atual para saber qual o pr�ximo estado e qual a pr�xima contagem.
	change_display_state:
		ldi YL, low(traffic_light_4 + 3)
		ldi YH, high(traffic_light_4 + 3)
		ld temp, Y
		cpi temp, 0
		breq switch_to_state_1
		cpi temp, 1
		breq switch_to_state_2

	; Mudar para estado VERMELHO.
	switch_to_state_0:
		ldi display_1, 0b00000111	; 7
		ldi display_2, 0b00000000	; 0
		jmp activate_displays
	
	; Mudar para estado VERDE.
	switch_to_state_1:
		ldi display_1, 0b00000101	; 5
		ldi display_2, 0b00000110	; 6
		jmp activate_displays
	
	; Mudar para estado AMARELO.
	switch_to_state_2:
		ldi display_1, 0b00000000	; 0
		ldi display_2, 0b00000100	; 4

	; Ativa o bit correspondente a porta que ativa o display no hardware (A4 para Display 1 e A5 para Display 2).
	activate_displays:
		ldi temp, 0b00010000
		or display_1, temp
		ldi temp, 0b00100000
		or display_2, temp

	ret

; Interrup��o do TIMER0, tratada a cada 5 milisegundos.
; Usada para alternar display ativado atualmente.
OC0A_Interrupt:
	; Salva valor de r16 e SREG na pilha para recuper�-los ao fim da interrup��o.
	push r16
	in r16, SREG
	push r16

	; Limpa flag de aviso de match em TIFR0 (contagem atingiu valor de TOP_0).
	ldi temp, 1<<OCF0A
	out TIFR0, temp

	; Verifica qual o display atualmente ativo e faz a troca.
	cpi display_id, 1
	breq switch_to_display_2
	
	; Ativa Display 1.
	subi display_id, 1
	out PORTC, display_1
	jmp back

	; Ativa Display 2.
	switch_to_display_2:
		subi display_id, -1
		out PORTC, display_2

	back:
		pop r16
		out SREG, r16
		pop r16

	reti

; Interrup��o do TIMER1, tratada a cada 1 segundo.
; Usada para mudan�a de estado de sem�foro e display, al�m da contagem de tempo restante do estado atual de cada sem�foro.
OC1A_Interrupt:
	; Salva valor de r16 e SREG na pilha para recuper�-los ao fim da interrup��o.
	push r16
	in r16, SREG
	push r16

	; Limpa flag de aviso de match em TIFR1 (contagem atingiu valor de TOP).
	ldi temp, 1<<OCF1A
	out TIFR1, temp

	; Conta cada segundo para verificar se o estado atual acabou.
	inc time_counter

	; Decrementa a contagem de cada sem�foro.
	dec traffic_light_counter_1
	dec traffic_light_counter_2
	dec traffic_light_counter_3
	dec traffic_light_counter_4

	; Chamada fun��o de controle de display (usada para alternar os valores exibidos).
	rcall display_control

	; Pega dura��o do estado atual na mem�ria e compara com o tempo passado. Caso sejam iguais, muda estado. Caso contr�rio, prossegue.
	ldi YL, low(states_durations)
	ldi YH, high(states_durations)
	add YL, state_counter
	clr temp
	adc YH, temp
	ld temp, Y
	cp temp, time_counter
	brne verify_traffic_light_1

	; Mudan�a de estado.
	change_state:
		; Zera contador de tempo.
		ldi time_counter, 0
		; Incrementa contador de estado. Se chegou ao �ltimo (estado 8), reseta contagem.
		inc state_counter
		cpi state_counter, 8
		brne continue
		ldi state_counter, 0

		continue:
			; Pega configura��o dos LEDs na mem�ria para atualizar o estado atual da porta B.
			ldi YL, low(b_states)
			ldi YH, high(b_states)
			add YL, state_counter
			clr temp
			adc YH, temp
			ld temp, Y
			out PORTB, temp

			; Pega configura��o dos LEDs na mem�ria para atualizar o estado atual da porta D.
			ldi YL, low(d_states)
			ldi YH, high(d_states)
			add YL, state_counter
			clr temp
			adc YH, temp
			ld temp, Y
			out PORTD, temp

	; Verifica se contador de cada sem�foro zerou. Se zerou, reseta contador e atualiza o estado atual na mem�ria para contagem do pr�ximo estado.
	; Verificador do Sem�foro 1: Entrando na Sandoval.
	verify_traffic_light_1:
		; Verifica se a contagem regressiva chegou a 0. Caso n�o tenha chegado, pula para a verifica��o do pr�ximo sem�foro.
		cpi traffic_light_counter_1, 0
		brne verify_traffic_light_2

		; Caso a contagem regressiva tenha chegado a 0, verifica se est� no �ltimo estado (estado 2).
		ldi YL, low(traffic_light_1 + 3)
		ldi YH, high(traffic_light_1 + 3)
		ld temp, Y
		cpi temp, 2
		breq reset_traffic_light_state_1

		; Caso a contagem regressiva n�o tenha chegado a 0, apenas incrementa contagem de estado, atualiza estado na mem�ria e contador regressivo.
		inc temp
		sts traffic_light_1 + 3, temp
		jmp reset_traffic_light_counter_1

		; Caso a contagem de estado tenha chegado ao �ltimo estado (estado 2), reseta e atualiza estado na mem�ria.
		reset_traffic_light_state_1:
			ldi temp, 0
			sts traffic_light_1 + 3, temp

		; Pega a dura��o do estado atual e seta a contagem regressiva para o pr�ximo estado.
		reset_traffic_light_counter_1:
			ldi YL, low(traffic_light_1)
			ldi YH, high(traffic_light_1)
			add YL, temp
			clr temp
			adc YH, temp
			ld temp, Y
			mov traffic_light_counter_1, temp

	; Verificador do Sem�foro 2: Sentido Stella Maris.
	verify_traffic_light_2:
		; Verifica se a contagem regressiva chegou a 0. Caso n�o tenha chegado, pula para a verifica��o do pr�ximo sem�foro.
		cpi traffic_light_counter_2, 0
		brne verify_traffic_light_3

		; Caso a contagem regressiva tenha chegado a 0, verifica se est� no �ltimo estado (estado 2).
		ldi YL, low(traffic_light_2 + 3)
		ldi YH, high(traffic_light_2 + 3)
		ld temp, Y
		cpi temp, 2
		breq reset_traffic_light_state_2

		; Caso a contagem regressiva n�o tenha chegado a 0, apenas incrementa contagem de estado, atualiza estado na mem�ria e contador regressivo.
		inc temp
		sts traffic_light_2 + 3, temp
		jmp reset_traffic_light_counter_2

		; Caso a contagem de estado tenha chegado ao �ltimo estado (estado 2), reseta e atualiza estado na mem�ria.
		reset_traffic_light_state_2:
			ldi temp, 0
			sts traffic_light_2 + 3, temp

		; Pega a dura��o do estado atual e seta a contagem regressiva para o pr�ximo estado.
		reset_traffic_light_counter_2:
			ldi YL, low(traffic_light_2)
			ldi YH, high(traffic_light_2)
			add YL, temp
			clr temp
			adc YH, temp
			ld temp, Y
			mov traffic_light_counter_2, temp

	; Verificador do Sem�foro 3: Saindo da Sandoval.
	verify_traffic_light_3:
		; Verifica se a contagem regressiva chegou a 0. Caso n�o tenha chegado, pula para a verifica��o do pr�ximo sem�foro.
		cpi traffic_light_counter_3, 0
		brne verify_traffic_light_4

		; Caso a contagem regressiva tenha chegado a 0, verifica se est� no �ltimo estado (estado 2).
		ldi YL, low(traffic_light_3 + 3)
		ldi YH, high(traffic_light_3 + 3)
		ld temp, Y
		cpi temp, 2
		breq reset_traffic_light_state_3

		; Caso a contagem regressiva n�o tenha chegado a 0, apenas incrementa contagem de estado, atualiza estado na mem�ria e contador regressivo.
		inc temp
		sts traffic_light_3 + 3, temp
		jmp reset_traffic_light_counter_3

		; Caso a contagem de estado tenha chegado ao �ltimo estado (estado 2), reseta e atualiza estado na mem�ria.
		reset_traffic_light_state_3:
			ldi temp, 0
			sts traffic_light_3 + 3, temp

		; Pega a dura��o do estado atual e seta a contagem regressiva para o pr�ximo estado.
		reset_traffic_light_counter_3:
			ldi YL, low(traffic_light_3)
			ldi YH, high(traffic_light_3)
			add YL, temp
			clr temp
			adc YH, temp
			ld temp, Y
			mov traffic_light_counter_3, temp

	; Verificador do Sem�foro 4: Sentido Ponta Verde.
	verify_traffic_light_4:
		; Verifica se a contagem regressiva chegou a 0. Caso n�o tenha chegado, pula para a transmiss�o do log dos sem�foros.
		
		cpi traffic_light_counter_4, 0
		brne transmit_setup

		; Caso a contagem regressiva tenha chegado a 0, verifica se est� no �ltimo estado (estado 2).
		ldi YL, low(traffic_light_4 + 3)
		ldi YH, high(traffic_light_4 + 3)
		ld temp, Y
		cpi temp, 2
		breq reset_traffic_light_state_4

		; Caso a contagem regressiva n�o tenha chegado a 0, apenas incrementa contagem de estado, atualiza estado na mem�ria e contador regressivo.
		inc temp
		sts traffic_light_4 + 3, temp
		jmp reset_traffic_light_counter_4

		; Caso a contagem de estado tenha chegado ao �ltimo estado (estado 2), reseta e atualiza estado na mem�ria.
		reset_traffic_light_state_4:
			ldi temp, 0
			sts traffic_light_4 + 3, temp

		; Pega a dura��o do estado atual e seta a contagem regressiva para o pr�ximo estado.
		reset_traffic_light_counter_4:
			ldi YL, low(traffic_light_4)
			ldi YH, high(traffic_light_4)
			add YL, temp
			clr temp
			adc YH, temp
			ld temp, Y
			mov traffic_light_counter_4, temp

	; Fun��es de transmiss�o de log para o Monitor Serial do Arduino.
	transmit_setup:
		; Chama rotina principal de transmiss�o.
		rjmp transmit
	
		; Impress�o da letra 'S'.
		print_S:
			rcall waiting
			ldi temp, 'S'
			sts UDR0, temp
			ret

		; Impress�o do n�mero '1' para identifica��o do sem�foro no log.
		print_1:
			rcall waiting
			ldi temp, '1'
			sts UDR0, temp
			ret

		; Impress�o do n�mero '2' para identifica��o do sem�foro no log.
		print_2:
			rcall waiting
			ldi temp, '2'
			sts UDR0, temp
			ret

		; Impress�o do n�mero '3' para identifica��o do sem�foro no log.
		print_3:
			rcall waiting
			ldi temp, '3'
			sts UDR0, temp
			ret

		; Impress�o do n�mero '4' para identifica��o do sem�foro no log.
		print_4:
			rcall waiting
			ldi temp, '4'
			sts UDR0, temp
			ret
		
		; Impress�o dos 'dois pontos' para identa��o.
		print_ddot:
			rcall waiting
			ldi temp, ':'
			sts UDR0, temp
			ret
	
		; Impress�o de 'espa�o' para identa��o.
		print_space:
			rcall waiting
			ldi temp, ' '
			sts UDR0, temp
			ret
	
		; Fun��o usada para aguardar libera��o do buffer antes das impress�es de log.
		waiting:
			lds div, UCSR0A
			sbrs div, UDRE0
	 		rjmp waiting
			ret

		; Impress�o dos dois �ltimos d�gitos do contador de cada sem�foro no log.
		less:
			cpi temp, 10
			brlo out_loop
			subi temp, 10
			inc div
			jmp less
			out_loop:
				mov aux, temp
				ldi temp, 48
				add div, temp 
				sts UDR0, div
				rcall waiting
				add temp, aux
				sts UDR0, temp
			ret
			
		; Impress�o do primeiro d�gito ('1') para contadores maiores que 100.
		less_100:
			rcall waiting
			ldi temp, '1'
			sts UDR0, temp
			ret

		; Impress�o da letra 'R' para sinalizar estado VERMELHO no log.
		print_red:
			rcall waiting
			ldi temp, 'R'
			sts UDR0, temp
			ret

		; Impress�o da letra 'G' para sinalizar estado VERMELHO no log.
		print_green:
			rcall waiting
			ldi temp, 'G'
			sts UDR0, temp
			ret

		; Impress�o da letra 'Y' para sinalizar estado VERMELHO no log.
		print_yellow:
			rcall waiting
			ldi temp, 'Y'
			sts UDR0, temp
			ret

		; Trasmite os tempos de cada sem�foro e seus estados.
		transmit:
			; Inicia rotina de identifica��o do contador do sem�foro 1.
			clr div
			clr aux
			rcall print_S
			rcall print_1
			rcall print_ddot
			rcall print_space

			; Aguarda libera��o do buffer.
			transmit2:
				clr div
				clr aux
				lds temp, UCSR0A
				sbrs temp, UDRE0
				rjmp transmit2

			; Verifica se o contador � maior que 100. Se for imprime '1', subtrai 100 e depois os dois digitos restantes.
			; Caso n�o seja, apenas imprime os dois d�gitos.
			mov temp, traffic_light_counter_1
			cpi temp, 100
			brlo out_less_100_1
			rcall less_100

			; Aguarda libera��o do buffer.
			transmit3:
				clr div
				clr aux
				lds temp, UCSR0A
				sbrs temp, UDRE0
				rjmp transmit3
		
			; Subtrai 100 do contador. Executado apenas caso o contador seja maior ou igual a 100.
			mov temp, traffic_light_counter_1
			subi temp, 100

			; Imprime os dois �ltimos d�gitos. Executada sempre.
			out_less_100_1:
				rcall less
		
			rcall print_space

			; Verifica o ID para saber qual o estado do sem�foro e imprimir corretamente no log.
			; id: 0 - VERMELHO, 1 - VERDE, 2 - AMARELO.
			ldi YL, low(traffic_light_1 + 3)
			ldi YH, high(traffic_light_1 + 3)
			ld temp, Y
			cpi temp, 2
			breq yellow
			cpi temp, 1
			breq green

			rcall print_red
			jmp transmit_S1end
			green:
			rcall print_green
			jmp transmit_S1end
			yellow:
			rcall print_yellow
		
		; Fim da transmiss�o do Sem�foro 1.
		transmit_S1end:
			; Inicia rotina de identifica��o do contador do sem�foro 2.
			clr div
			clr aux
			rcall print_space
			rcall print_S
			rcall print_2
			rcall print_ddot
			rcall print_space

			; Aguarda libera��o do buffer.
			transmit2_2:
				clr div
				clr aux
				lds temp, UCSR0A
				sbrs temp, UDRE0
				rjmp transmit2_2
	
			; Verifica se o contador � maior que 100. Se for imprime '1', subtrai 100 e depois os dois digitos restantes.
			; Caso n�o seja, apenas imprime os dois d�gitos.
			mov temp, traffic_light_counter_2
			cpi temp, 100
			brlo out_less_100_2
			rcall less_100

			; Aguarda libera��o do buffer.
			transmit3_2:
				clr div
				clr aux
				lds temp, UCSR0A
				sbrs temp, UDRE0
				rjmp transmit3_2
		
			; Subtrai 100 do contador. Executado apenas caso o contador seja maior ou igual a 100.
			mov temp, traffic_light_counter_2
			subi temp, 100
		
			; Imprime os dois �ltimos d�gitos. Executada sempre.
			out_less_100_2:
				rcall less

			rcall print_space

			; Verifica o ID para saber qual o estado do sem�foro e imprimir corretamente no log.
			; id: 0 - VERMELHO, 1 - VERDE, 2 - AMARELO.
			ldi YL, low(traffic_light_2 + 3)
			ldi YH, high(traffic_light_2 + 3)
			ld temp, Y
			cpi temp, 2
			breq yellow2
			cpi temp, 1
			breq green2

			rcall print_red
			jmp transmit_S2end
			green2:
			rcall print_green
			jmp transmit_S2end
			yellow2:
			rcall print_yellow
		
		; Fim da transmiss�o do Sem�foro 2.
		transmit_S2end:
			; Inicia rotina de identifica��o do contador do sem�foro 3.
			clr div
			clr aux
			rcall print_space
			rcall print_S
			rcall print_3
			rcall print_ddot
			rcall print_space
								
			; Aguarda libera��o do buffer.
			transmit2_3:
				clr div
				clr aux
				lds temp, UCSR0A
				sbrs temp, UDRE0
				rjmp transmit2_3

			; Verifica se o contador � maior que 100. Se for imprime '1', subtrai 100 e depois os dois digitos restantes.
			; Caso n�o seja, apenas imprime os dois d�gitos.
			mov temp, traffic_light_counter_3
			cpi temp, 100
			brlo out_less_100_3
			rcall less_100
		
			; Aguarda libera��o do buffer.
			transmit3_3:
				clr div
				clr aux
				lds temp, UCSR0A
				sbrs temp, UDRE0
				rjmp transmit3_3
		
			; Subtrai 100 do contador. Executado apenas caso o contador seja maior ou igual a 100.
			mov temp, traffic_light_counter_3
			subi temp, 100

			; Imprime os dois �ltimos d�gitos. Executada sempre.
			out_less_100_3:
				rcall less

			rcall print_space
		
			; Verifica o ID para saber qual o estado do sem�foro e imprimir corretamente no log.
			; id: 0 - VERMELHO, 1 - VERDE, 2 - AMARELO.
			ldi YL, low(traffic_light_3 + 3)
			ldi YH, high(traffic_light_3 + 3)
			ld temp, Y
			cpi temp, 2
			breq yellow3
			cpi temp, 1
			breq green3

			rcall print_red
			jmp transmit_S3end
			green3:
			rcall print_green
			jmp transmit_S3end
			yellow3:
			rcall print_yellow

		; Fim da transmiss�o do Sem�foro 3.
		transmit_S3end:
			; Inicia rotina de identifica��o do contador do sem�foro 4.
			clr div
			clr aux
			rcall print_space
			rcall print_S
			rcall print_4
			rcall print_ddot
			rcall print_space

			; Aguarda libera��o do buffer.
			transmit2_4:
				clr div
				clr aux
				lds temp, UCSR0A
				sbrs temp, UDRE0
				rjmp transmit2_4

			; Verifica se o contador � maior que 100. Se for imprime '1', subtrai 100 e depois os dois digitos restantes.
			; Caso n�o seja, apenas imprime os dois d�gitos.
			mov temp, traffic_light_counter_4
			cpi temp, 100
			brlo out_less_100_4
			rcall less_100

			; Aguarda libera��o do buffer.
			transmit3_4:
				clr div
				clr aux
				lds temp, UCSR0A
				sbrs temp, UDRE0
				rjmp transmit3_4
		
			; Subtrai 100 do contador. Executado apenas caso o contador seja maior ou igual a 100.
			mov temp, traffic_light_counter_4
			subi temp, 100

			; Imprime os dois �ltimos d�gitos. Executada sempre.
			out_less_100_4:
				rcall less
		
			rcall print_space
								
			; Verifica o ID para saber qual o estado do sem�foro e imprimir corretamente no log.
			; id: 0 - VERMELHO, 1 - VERDE, 2 - AMARELO.
			ldi YL, low(traffic_light_4 + 3)
			ldi YH, high(traffic_light_4 + 3)
			ld temp, Y
			cpi temp, 2
			breq yellow4
			cpi temp, 1
			breq green4

			rcall print_red
			jmp transmit_S4end
			green4:
			rcall print_green
			jmp transmit_S4end
			yellow4:
			rcall print_yellow
														
		; Fim da transmiss�o do Sem�foro 4 e impress�o de 'quebra de linha' para identa��o do log.
		transmit_S4end:
			lds div, UCSR0A
			sbrs div, UDRE0
			rjmp transmit_S4end
			ldi temp, 10
			sts UDR0, temp

	; Recupera valores originais de r16 e do SREG, e retoma execu��o do loop principal, reativando as interrup��es.
	return:
		pop r16
		out SREG, r16
		pop r16
	
	reti

setup:
	; Guarda os bits de estados relativos aos sem�foros da porta B no espa�o de mem�ria da SRAM reservado em b_states.
	ldi temp, 0b00100100
	sts b_states, temp
	ldi temp, 0b00001001
	sts b_states + 1, temp
	ldi temp, 0b00010001
	sts b_states + 2, temp
	ldi temp, 0b00100001
	sts b_states + 3, temp
	ldi temp, 0b00100010
	sts b_states + 4, temp
	ldi temp, 0b00100100
	sts b_states + 5, temp
	ldi temp, 0b00100100
	sts b_states + 6, temp
	ldi temp, 0b00100100
	sts b_states + 7, temp

	; Guarda os bits de estados relativos aos sem�foros da porta D no espa�o de mem�ria da SRAM reservado em d_states.
	ldi temp, 0b10010000
	sts d_states, temp
	ldi temp, 0b10010000
	sts d_states + 1, temp
	ldi temp, 0b10010000
	sts d_states + 2, temp
	ldi temp, 0b10000100
	sts d_states + 3, temp
	ldi temp, 0b10001000
	sts d_states + 4, temp
	ldi temp, 0b10010000
	sts d_states + 5, temp
	ldi temp, 0b00110000
	sts d_states + 6, temp
	ldi temp, 0b01010000
	sts d_states + 7, temp

	; Guarda os bits de dura��o (em segundos) relativos aos 8 estados configurados.
	ldi temp, 18
	sts states_durations, temp
	ldi temp, 26
	sts states_durations + 1, temp
	ldi temp, 4
	sts states_durations + 2, temp
	ldi temp, 56
	sts states_durations + 3, temp
	ldi temp, 4
	sts states_durations + 4, temp
	ldi temp, 3
	sts states_durations + 5, temp
	ldi temp, 15
	sts states_durations + 6, temp
	ldi temp, 4
	sts states_durations + 7, temp

	; Guarda os tempos (em segundos) do estado de cada sem�foro, na ordem: VERMELHO, VERDE e AMARELO. No �ltimo byte, guarda id do estado atual.
	; id: 0 - VERMELHO, 1 - VERDE, 2 - AMARELO.
	; Sem�foro 1: Entrando na Sandoval.
	ldi temp, 100
	sts traffic_light_1, temp
	ldi temp, 26
	sts traffic_light_1 + 1, temp
	ldi temp, 4
	sts traffic_light_1 + 2, temp
	ldi temp, 0
	sts traffic_light_1 + 3, temp

	; Sem�foro 2: Sentido Stella Maris.
	ldi temp, 40
	sts traffic_light_2, temp
	ldi temp, 86
	sts traffic_light_2 + 1, temp
	ldi temp, 4
	sts traffic_light_2 + 2, temp
	ldi temp, 0
	sts traffic_light_2 + 3, temp

	; Sem�foro 3: Saindo da Sandoval.
	ldi temp, 111
	sts traffic_light_3, temp
	ldi temp, 15
	sts traffic_light_3 + 1, temp
	ldi temp, 4
	sts traffic_light_3 + 2, temp
	ldi temp, 0
	sts traffic_light_3 + 3, temp

	; Sem�foro 4: Sentido Ponta Verde.
	ldi temp, 70
	sts traffic_light_4, temp
	ldi temp, 56
	sts traffic_light_4 + 1, temp
	ldi temp, 4
	sts traffic_light_4 + 2, temp
	ldi temp, 0
	sts traffic_light_4 + 3, temp

	; Inicializa o programa no primeiro estado, a partir do tempo 0s.
	ldi time_counter, 0
	ldi state_counter, 0

	; Inicializa com Display 1 ativado.
	ldi display_id, 1

	; Inicializa a contagem regressiva para o estado 1 dos sem�foros.
	ldi traffic_light_counter_1, 18
	ldi traffic_light_counter_2, 18
	ldi traffic_light_counter_3, 111
	ldi traffic_light_counter_4, 48

	;initialize USART
	ldi temp, high (UBRRvalue) ;baud rate
	sts UBRR0H, temp
	ldi temp, low (UBRRvalue)
	sts UBRR0L, temp

	ldi temp, (3<<UCSZ00)
	sts UCSR0C, temp

	ldi temp, (0<<RXEN0)|(1<<TXEN0)
	sts UCSR0B, temp; enable receive and transmit
	
	rjmp start

start:
    ; Inicializa pilha.
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

	; Seta as portas B, C e D como sa�da (bit 1 em DDR) e configura LEDs e displays com estado inicial.
	ldi temp, 0b11111111
	out DDRB, temp
	ldi temp, 0b00100100	; b_leds
	out PORTB, temp

	ldi temp, 0b11111111
	out DDRD, temp
	ldi temp, 0b10010000	; d_leds
	out PORTD, temp

	ldi temp, 0b11111111
	out DDRC, temp
	ldi display_1, 0b00010100	; 4
	ldi display_2, 0b00101000	; 8
	out PORTC, display_1
	
	; TIMER 1
	; Define CLOCK (16MHz), PRESCALE de 256 (0b100 em CS), modo de opera��o CTC (0b100 em WGM) e TOP (c�lculo para 1 segundo).
	#define CLOCK 16.0e6
	.equ PRESCALE = 0b100
	.equ PRESCALE_DIV = 256
	#define DELAY 1
	.equ WGM = 0b0100
	.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY))
	.if TOP > 65535
	.error "TOP is out of range"
	.endif

	; Seta valor do TOP em OCR1A (comparador), seta o modo de opera��o em TCCR1A/TCCR1B e seta o PRESCALE em TCCR1B.
	ldi temp, high(TOP)
	sts OCR1AH, temp
	ldi temp, low(TOP)
	sts OCR1AL, temp
	ldi temp, ((WGM&0b11) << WGM10)
	sts TCCR1A, temp
	ldi temp, ((WGM>> 2) << WGM12)|(PRESCALE << CS10)
	sts TCCR1B, temp
	lds temp, TIMSK1
	sbr temp, 1<<OCIE1A
	sts TIMSK1, temp

	; TIMER 0
	; Define CLOCK_0 (16MHz), PRESCALE_0 de 1024 (0b101 em CS), modo de opera��o CTC (0b010 em WGM) e TOP_0 (c�lculo para 5 milisegundos).
	#define CLOCK_0 16.0e6
	.equ PRESCALE_0 = 0b101
	.equ PRESCALE_DIV_0 = 1024
	#define DELAY_0 0.005
	.equ WGM_0 = 0b010
	.equ TOP_0 = int(0.5 + ((CLOCK_0/PRESCALE_DIV_0)*DELAY_0))
	.if TOP_0 > 255
	.error "TOP_0 is out of range"
	.endif

	; Seta valor do TOP_0 em OCR0A (comparador), seta o modo de opera��o em TCCR0A/TCCR0B e seta o PRESCALE_0 em TCCR0B.
	ldi temp, TOP_0
	out OCR0A, temp
	ldi temp, ((WGM_0&0b11) << WGM00)
	out TCCR0A, temp
	ldi temp, ((WGM_0>> 2) << WGM02)|(PRESCALE_0 << CS00)
	out TCCR0B, temp
	lds temp, TIMSK0
	sbr temp, 1<<OCIE0A
	sts TIMSK0, temp

	sei
	 
main_loop:
	rjmp main_loop