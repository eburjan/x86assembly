;	---- EZ a  legutobbi!!!!
.286p
.model	small
.stack	100h
.data
buffer1		db	441	dup (23)	;bufferban 17h lesz
.code
bufsize		equ	1B9h			;a buffer merete
authorid	db	'VU-meter program for SoundBlaster.',0dh,0ah,'$'
reseth		db	'Nem sikerÅlt a DSP-t reset-elni.',0dh,0ah,'$'
recfile		db	'recfile.dat',0
dspdata		db	?		;dspwrite-nak atadott parameter
irqdone		db	0		;kezeltuk-e az IT-t 'flag'
;---- a hangkartya altalanos jellemzoi
origirq		dd	0		;az eredeti irq kezelo cime
base		dw	220h		;baziscim
irq		db	5h		;megszakitas szam
irqint		db	0Dh		;IRQ5=INT13
dmachan		db	1h		;DMA-csatorna szam
;---- vezerloregiszterek cimei
dmamask		equ	0ah		;maszkregiszter
dmabyteptr	equ	0ch		;byte-mutato torlese-regiszter
dmamode		equ	0bh		;mod-regiszter
;---- a dma vezerlonek szukseges valtozok
dmapage		db	0		;dma lap szama
dmaoffset	dw	0		;dma lapon beluli eltolas
dmalength	dw	0		;atvitel hossza
;---- dma csatorna erteketol fuggo adatok
cpageio		dw	83h		;lapregiszter i/o cim
coffsio		dw	02h		;cimregiszter i/o cim
csizeio		dw	03h		;szamlalo i/o cim [current]
recmode		db	45h		;felvetel vezerlo byte-ja
disdma		db	5h		;dma tiltasa
endma		db	1h		;dma engedelyezese
enirq		db	0DFh		;konst. az irq engedelyezesehez
disirq		db	20h		;konst. az irq tiltasahoz
;---- grafikaval kapcsolatos valtozok
xkoord:		dw	255	;racs bal felso koord.
ykoord:		dw	100	;-||-
szin:		db	8	;racs szine
oszin:		db	4	;oszlop szine
hszin:		db	0	;hatter szin
fhossz:		dw	260	;fuggoleges vonal hossza
vhossz:		dw	120	;vizszintes vonal hossza
fvonszam:	dw	13	;a fuggoleges vonalak szama
fvonlep	:	dw	10	;a fuggoleges vonalak kozti tavolsag
vvonszam:	dw	27	;a vizszintes vonalak szama
vvonlep	:	dw	10	;vizszintes vonalak kozti tavolsag

bitmaszk: 	db 	128,64,32,16,8,4,2,1	;vonalhuzashoz kell
fmask:		db	00ffh,007fh,003fh,001fh,000fh,0007h,0003h,0001h
lmask:		db	0080h,00c0h,00e0h,00f0h,00f8h,00fch,00feh,00ffh
r0:		dw      0
r1:     	dw      0
r2:		dw      0
r3:		dw      0
yy:		dw	0
x1:		dw	0
x2:		dw      0
y1:		dw      0
y2:		dw      0
x:		dw	0
y:		dw	0
fsz:		dw	0
vsz:		dw	0
;---- DSP reset - a hangkartya DSP-t inicializalja
dspreset	proc	near
		mov	DX,base
		add	DL,06h		;DX:=226h, DSP reset
		mov	AL,01h		;
		out	DX,AL		;01h ertek kikuldese
		mov	CX,100h		;varakozas lesz, CX:=100h
		rep 	lodsb		;varakozas, CX-=1
		xor	AL,AL		;AL:=0
		out	DX,AL		;00h kikuldese
		add	DL,08h		;DX:=22E, data available
		mov	CX,128		;loop-hoz
waitdata:	in	AL,DX		;beolvasas a 22E-rol
		and	AL,80h		;adat ervenyes? = 7.bit 1?
		jnz	dsptest		;kiugras, ha ervenyes az adat
		loop	waitdata	;nem ervenyes, ujra
		jmp	bad		;lejart a ciklus=hiba
dsptest:	mov	CX,10000	;loop-hoz
		sub	DL,04h		;DX:=22A, dsp read data
waitdsp:	in	AL,DX
		cmp	AL,0aah		;AAh ertek varasa - reset kesz jele
		jz	aaok		;AAh megjott
		loop	waitdsp
bad:		xor	AL,AL		;AL:=0, =rossz
		jmp	resetend
aaok:		mov	AL,1h
resetend:
		ret
dspreset	endp
;---- DSP write - kikuld a DSP-re egy byte-ot (parancsot)
dspwrite	proc	near
		mov	dspdata,AL	;AL-ben KELL atadni a parametert
		mov	DX,22Ch		;dsp-command
regfree:	in	AL,DX
		and	AL,80h		;szabad mar a regiszter?
		jnz	regfree
		mov	AL,dspdata
		out	DX,AL		;command/data irasa
		ret
dspwrite	endp
;---- out makro - a reg-ben levo adatot kikuldi a valtozoban levo cimre
movo		MACRO	valtozo,reg
		pusha
		mov	CX,0FFFFh	;varakozas
		rep	lodsb		;
		mov	DX,valtozo	;DX<- io cim
		mov	AL,reg		;AL<- adat
		out	DX,AL		;kivitel
		popa
ENDM
;---- a DMA vegen keletkezo IT-t kezeli:
dmairq		proc	near
		push	DS
		push	ES
		pusha
		mov	AX,SEG @data
		mov	DS,AX		;DS:=az adatszegmens cime
		mov	DX,base
		add	DX,0eh		;DX:=22E, DSP data available
		in	AL,DX		;az IT nyugtazasa a DSP fele
		mov	AL,1
		mov	irqdone,AL	;az IT kezelese megtortent
	        cli
	        in	AL,21h
	        or	AL,disirq
	        out	21h,AL		;IT letiltasa
		movo	dmamask,disdma
	        mov	AL,0d0h
	        call	DSPwrite		;DMA stop
	        mov 	DX,WORD PTR origirq
	        mov 	AX,WORD PTR origirq+2	;regi IT vektor vissza
	        push	DS
	        mov	DS,AX
	        mov	AL,irqint
        	mov	AH,25h
	        int	21h			;regi IT vektor beallitva
	        pop	DS
	        sti
endirq:		mov	AL,20h		;megszakitas vege jelzes az 8059-nek
		out	20h,AL		;20-as cimre a 20-as jelzes
		popa
		pop	ES
		pop	DS
		iret
dmairq		endp
;---- ez egy teszt eljaras, amely a buffer-t kiirja egy file-ba
writefile       proc    near
                mov     AX,SEG @code
             	mov     DS,AX
                mov     DX,OFFSET recfile
               	mov     AH,3ch
                mov     CX,0h
                int     21h                    ;file-t csinal
                mov     BX,AX
                mov     AX,SEG @data
                mov     DS,AX
                mov     DX,OFFSET buffer1
                mov     CX,bufsize
                mov     AH,40h
                int     21h                     ;iras
                mov     AH,3eh
                int     21h                     ;file-handle-t bezarja
                ret
writefile       endp
;---- 
rajz		proc			;oszlop rajzolas 
		mov	AL,byte ptr [hszin]	;oszlopszinbe a hatterszin
		mov	byte ptr [oszin],AL
	
		call	var			;varakozunk az elektronsug.-ra
		call	bar			;oszlop rajzolasa
		mov	byte ptr [oszin],4	;oszlopszin visszatoltese
		call 	seged			;oszlop par.-i valtoztak
		call 	fvon			;racs megrajzolasa
		call	vvon
		mov	BX,word ptr [y2]
		sub 	BX,word ptr [yy]
		mov	word ptr [y1],BX	;y1:=y2-yy : 
		call 	bar			;uj oszlop rajzolasa
		ret
rajz		endp
;---- 
var		proc		;az elekktronsugar bal felso sarokban
var:				;es csak akkor valtoztat,hogy ne ugraljon a
		mov DX,03dah	;kep	CRTC
		in AL,DX
		and AL,8	
		jz var
		ret		;visszater, ha az e-sugar a bal feso sarokban
var		endp		;van
;---- 
seged		proc			;segedvaltozok beallitasa
		mov 	AX,word ptr [xkoord]
		mov	word ptr [x],AX
		mov	AX,word ptr [ykoord]
		mov	word ptr [y],AX
		mov	AX,word ptr [fvonszam]
		mov	word ptr [fsz],AX
		mov	AX,word ptr [vvonszam]
		mov	word ptr [vsz],AX
		ret
seged		endp
;---- 
fvon		proc		;fugg. vonalakat huzza meg a racsban
fv:
		mov	AX,80		;AX-ben a kepernyo logikai hossza
		mul	word ptr [ykoord]
		mov 	DI,word ptr [x]
		shr	DI,3
		mov 	SI,DI
		shl	SI,3
		add	DI,AX		;racs bal felso mem-cimenek a szamaitasa
		mov	AX,word ptr [x]
		sub	AX,SI
		mov 	SI,AX
		lea	BX,bitmaszk	;a byte-ban a bit-pozicio kiszamitasa
		mov	AH,[BX+si]
		mov	AL,8
		mov	DX,03ceh
		out	DX,AX		;ennek kivitele
		mov 	CX,word ptr [fhossz]	;CX-ben a fugg. vonal hossza
		mov	AX,0a000h
		mov	ES,AX			;ES video memoria kezdocime
		mov	AL,byte ptr [szin]	;AL <- szin
ccikl:
		mov	AH,ES:[di]		;ES:[DI] kiolvasasa (kell)
		mov	es:[di],AL		;ES:[DI] irasa
		add	DI,80			;fugg vonal kovetkezo pontja
		loop	ccikl			;amilyen hosszu a vonal
		mov	AX,word ptr [x]
		add	AX,word ptr [fvonlep]
		mov	word ptr [x],AX		;vonal parametereinek beallitasa
		dec 	word ptr [fsz]
		jnz	fv			;amig kell vonal
		ret
fvon 		endp
;---- 
vvon		proc			;vizsz. vonalak rajzolasa
vv:
		mov 	AX,0a000h
		mov	ES,AX
		mov	AX,80
		mul	word ptr [y]
		mov	DI,word ptr [xkoord]
		mov	DX,DI
		shr 	DI,3
		add	DI,AX		;kezdopont kiszamitasa eddig
		mov	CX,DX
		add	CX,word ptr [vhossz]
		dec	CX
		lea	BX,lmask	;vizsz. vonalban levo egesz byte-ok szama
		mov	AL,CL		;ezeket gyorsan felulirja
		and	AL,7
		xlat
		mov	SI,AX
		lea	BX,fmask
		mov	AL,DL
		and	AL,7
		xlat
		shr	CX,3
		shr	DX,3
		sub	CX,DX
		mov	DX,03ceh
		jz	egy
		dec	CX
		mov	AH,AL
		mov	AL,8
		out	DX,AX
		mov	AL,ES:[di]
		mov	AL,byte	ptr [szin]
		stosb
		jcxz	utolso
		mov	AX,0ff08h
		out	DX,AX
		mov	AL,byte ptr [szin]
		rep	stosb
utolso:					;kiviszi a vonal maradek reszet, ha van
		mov 	AX,SI
		mov	AH,AL
		mov	AL,8
		out	DX,AX
		mov	AL,ES:[di]
		mov	AL,byte ptr [szin]
		stosb
		jmp	vvege
egy:
		mov	BX,SI
		and	AL,BL
		mov	AH,AL
		mov	AL,8
		out	DX,AX
		mov	AL,ES:[di]
		mov	AL,byte ptr [szin]
		stosb
vvege:
		mov	AX,word ptr [y]
		add	AX,word ptr [vvonlep]
		mov	word ptr [y],AX
		dec	word ptr [vsz]
		jnz	svvon
		jmp 	svege
svvon:
		jmp vv
svege:
		ret
vvon		endp
;---- 
bar		proc		;oszlopot rajzolja ki
		mov	AX,0a000h
		mov	ES,AX
		mov	AX,80
		mul	word ptr [y1]
		mov	DI,word ptr [x1]
		mov	DX,DI
		shr	DI,3
		add	DI,AX
		mov	CX,word ptr [x2]
		lea	BX,lmask
		mov	AL,CL
		and	AL,7
		xlat
		mov	SI,AX
		lea	BX,fmask
		mov	AL,DL
		and	AL,7
		xlat
		shr	CX,3
		shr	DX,3
		sub	CX,DX
		mov	DX,03ceh
		jnz	tovabb
		jmp	nincs_byte
tovabb:		mov	BX,word ptr [y2]
		sub	BX,word ptr [y1]
		inc	BX
		dec	CX
		mov	AH,AL
		mov	AL,8
		out	DX,AX
		mov	word ptr [r0],BX
		mov	word ptr [r1],DI
		mov	AL,byte ptr [oszin]
ficikl:
		mov	AH,ES:[di]
		mov	es:[di],AL
		add	DI,80
		dec	BX
		jnz	ficikl
		mov	DI,word ptr [r1]
		inc	di
		jcxz	nx
		mov	AX,0ff08h
		out	DX,AX
		mov	AL,byte ptr [oszin]
		mov	BX,word ptr [r0]
		mov	word ptr [r1],DI
		mov	word ptr [r2],CX
		mov	word ptr [r3],DI
		push	si
		mov	SI,CX
		mov	DX,DI
mdcikl:
		mov	CX,SI
		mov	DI,DX
		rep	stosb
		add	DX,80
		dec	BX
		jnz	mdcikl
		mov	DX,03ceh
		pop	si
		mov	DI,word ptr [r1]
		add	DI,word ptr [r2]
nx:
		mov	AX,SI
		mov	AH,AL
		mov	AL,8
		out	DX,AX
		mov	BX,word ptr [r0]
		mov	AL,byte ptr [oszin]
lacikl:
		mov	AH,ES:[di]
		mov	es:[di],AL
		add	DI,80
		dec	BX
		jnz	lacikl
		jmp	exit
nincs_byte:
		mov	BX,SI
		and	AL,BL
		mov	AH,AL
		mov	AL,8
		out	DX,AX
		mov	CX,word ptr [y2]
		sub	CX,word ptr [y1]
		inc	CX
		mov	AL,byte ptr [oszin]
oncikl:
		mov	AH,ES:[di]
		mov	es:[di],AL
		add	DI,80
		loop	oncikl
exit:
		ret
bar		endp

start:
		mov 	AX,SEG @code
		mov 	DS,AX
		mov	AX,12h
		int	10h		;640*480/16 szinu mod beallitasa
		mov	AL,5
		mov	AH,2		;2 es irasmod: 3CE $8. reg.-be kiviszi
 		mov 	DX,03ceh	;a bitmaszkot.
		out 	DX,AX

		mov	word ptr [x1],0		;innen a kezdeti parameterek
		mov	word ptr [x2],639	;beallitasa
		mov	word ptr [y1],0
		mov	word ptr [y2],479

		mov	AL,byte ptr [hszin]
		mov	byte ptr [oszin],AL

		call	bar			;ITT allitja be a hatteret

		mov	byte ptr [oszin],4	;visszaallitja az oszlopszint

		mov 	AX,word ptr [fvonszam]
		dec	AX
		mul	word ptr [fvonlep]
		mov	BX,word ptr [xkoord]
		add	BX,AX
		mov	word ptr [x2],BX

		mov	AX,word ptr [vvonszam]
		dec	AX
		mul	word ptr [vvonlep]
		mov	BX,word ptr [ykoord]
		add	BX,AX
		mov	word ptr [y2],BX

		sub	word ptr [x2],50

		mov	AX,word ptr [xkoord]
		add	AX,50
		mov	word ptr [x1],AX

		mov	BX,word ptr [y2]
		sub 	BX,2
		mov	word ptr [y1],BX
                               		;eddig kezdeti koord. beall.
		call	seged		;masolatot keszit a valtozokrol
		call 	fvon
		call	vvon		;racsot kiteszi
;GRAFIKAI RESZ VEGE
;		mov	AX,CS			;@code volt itt
;		mov	DS,AX
;		mov	DX,OFFSET CS:authorid
;		mov	AH,9h
;		int	21h			;szoveg kiiras
		call	dspreset		;DSP inicializalasa
		cmp	AL,1			;ha AL=1 akkor sikerult
		jz	foly			;jo, mehetunk tovabb
		jmp	resethiba		;nem sikerult -> kilepes
foly:		mov	AL,0D3h
		call	dspwrite		;dsp kimenet letiltas
		mov	AX,bufsize
		mov	dmalength,AX		;dmalength:=bufsize
		mov	AX,SEG @data	;!= mov AX,DS
		xor	DX,DX

;az AX:DX-ben levo cimet atalakitjuk a dma-nak emesztheto formara

		mov	CL,AH		;CL:=szegmenscim felso bitjei
		shr	CL,4		;also 4 kilove, csak a felso 4 kell
		shl	AX,4		;AX:=16*szegmensresz(utolso hi. 0 lesz)
		add	DX,AX		;DX:=szegmens+offset
		mov	AH,CL		;a lapszam betoltese a AH-ba
		adc	AH,0h		;AH+=00 + a CF flag (ha atvitel volt
		mov	CX,DX		;az osszeg negaltja a mAX ssize
		neg	CX		;

;atalakitas vege: AH=lapszam, DX=lapeltolas, CX=max. felhasznalhato byte-ok
		mov	dmapage,AH
		mov	dmaoffset,DX
		mov	dmalength,bufsize
		mov	AL,42h		;mintaveteli ido beallitasa-> DSP
		call	dspwrite	;SB16 !
		mov	AL,56h          ;felso mintaveleti byte 22050=5622h
		call	dspwrite	;SB16 !
		mov	AL,22h          ;also mintaveteli byte
		call	dspwrite	;SB16 !
;IT vektor atirasa
		cli
		mov	AL,irqint
		mov	AH,35h
		int	21h		;ES:BX -ben lesz a IT-vektor
		mov	word ptr origirq,BX
		mov	word ptr origirq+2,ES
		lea	DX,dmairq	;DX:=offset dmairq
		mov	AX,CS
		push	DS
		mov	DS,AX		;DS:DX-ben az uj kezelo cime
		mov	AL,irqint	;AL:=Dh (13)
		mov	AH,25h
		int	21h		;uj vector betoltve
		pop	DS
		in	AL,21h
		and	AL,enirq	;1-re allitani a irq. bitet
		out	21h,AL		;maszk ki
		sti
;IT vektor atirva
; a felvetel inditasa

		movo	dmamask,disdma		;DMA tiltasa
	        xor     AL,AL
	        out     dmabyteptr,AL		;a DMA bajtmutato torlese
		movo	dmamode,recmode		;felvetel modja

;a csatorna parametereinek beallitasa a DMA vezerlo fele

	        push    DX
		movo	cpageio,dmapage		;lap kikuldese
	        mov     BX,dmalength
		movo	csizeio,BL		;atvitel merete ki.
		movo	csizeio,BH
	        mov     BX,dmaoffset
		dec	BX
		movo	coffsio,BL		;eltolas ki.
		movo	coffsio,BH
	        pop     DX

;parameterek beallitva

		movo	dmamask,endma
	        cli				;DSP programozasahoz
	        mov     AL,0C8h			;transfer mode byte
	        call    dspwrite
	        mov     AL,10h			;M/S-mono/sztereo byte
	        call    dspwrite
	        mov     BX,dmalength		;hossz beallitasa
	        mov     AL,BL
	        call    dspwrite
		mov	AL,BH
		call	dspwrite		;felvetel indul
		sti
		mov	irqdone,0h		;IT meg nincs kezelve

varakoz:	mov	AL,irqdone		;atvitel vegere varas
		cmp	AL,1
		jnz	varakoz			;ugras, ha AL!=1

;az atlagolas kezdodik

		mov	AX,SEG @data
		mov	DS,AX
		mov	AX,0
		mov	DX,0
		mov	CX,0
		mov	BX,OFFSET DS:buffer1
cikl:		mov	DL,DS:[BX]
		add	AX,DX
		cmp	CL,7Fh		;igy fog 80h-szor vegrehajtodni
		jz	exitc
		inc	CL
		inc	BX
		jmp	cikl		;eddig AX novelodik
exitc:		mov	BL,80h		;atlagoljuk. (80h)-szor volt osszeadas
		div	BL
;atlagolas vege
;tesztkiiras kezdodik
;		mov	byte ptr atlag,AL
;		push	CS
;		pop	DS
;		mov	DX,OFFSET atlag
;		mov	AH,9h
;		int	21h
;teszkiiras vege

		mov	BX,SEG @code
		mov	DS,BX
		mov	AH,0
		mov	word ptr [yy],AX	;atadjuk a rajznak az atlagot
		call	rajz

		mov	AH,02h			;billentyu statusz lekerdezes
		int	16h
		and	AL,04h			;csak a ctrl erdekel
		cmp	AL,04h			;lenyomtak e a 'ctrl'-t?
		jz	jobill			;nem
		jmp	foly			;igen
jobill:		call	writefile		;test-fileba iras
		jmp	vege			;mukodes vege
resethiba:	
		mov	AX,3
		int	10h			;grafika off
		push	CS
		pop	DS
		mov	DX,OFFSET reseth	;hibauzenet kiirasa
		mov	AH,9h
		int	21h			;szoveg kiiras
vege:		
		mov	AX,3
		int	10h			;grafika off
		mov	AH,4ch			;vezerles visszaadasa
		int	21h
END		start
