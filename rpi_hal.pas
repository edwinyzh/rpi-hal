unit rpi_hal; // V5.0 // 2019-03-17
{ RPI_hal:
* Free Pascal Hardware abstraction library for the Raspberry Pi
* Copyright (c) 2012-2018 Stefan Fischer
***********************************************************************
*
* RPI_hal is free software: you can redistribute it and/or modify
* it under the terms of the GNU Lesser General Public License as 
* published by the Free Software Foundation, either version 3 
* of the License, or (at your option) any later version.
*
* RPI_hal is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU Lesser General Public License for more details.
*
* You should have received a copy of the GNU Lesser General Public License
* along with RPI_hal. If not, see <http://www.gnu.org/licenses/>.
*
*********************************************************************** 

  requires minimum FPC Version: 2.4.6
  support for the following RPI-Models: A,B,A+,B+,Pi2B,Zero,Pi3B...
  !!!!! In your program, pls. use following uses sequence: !!!!!
  uses cthreads,rpi_hal,<yourunits>...
  required sw tools (apt-get install curl whois):
  - curl		(PKG: curl)  is used by function RPI_MAINT.
  - mkpasswd	(PKG: whois) is used by function LNX_ChkUsrPwdValid.
  Info:  http://wiki.freepascal.org/Lazarus_on_Raspberry_Pi
  pls. report bugs and discuss code enhancements here:
  Forum: http://www.lazarus.freepascal.org/index.php/topic,20991.0.html 
  Supported by the H2020 Project # 664786 - Reservoir Computing with Real-Time Data for Future IT
}
  {$MODE OBJFPC}
  { $T+}
  {$R+} {$Q+}
  {$H+}  // Ansistrings
  { $ PACKRECORDS C} 
  {$PACKRECORDS 16} 
  { $ ALIGN 32}
  {$MACRO ON}
  {$HINTS OFF}
Interface 
uses {$IFDEF UNIX}    cthreads,initc,ctypes,unixtype,cmem,BaseUnix,Unix,unixutil,errors, {$ENDIF} 
     {$IFDEF WINDOWS} windows, {$ENDIF} 
	 crt,typinfo,sysutils,dateutils,Classes,Process,math,inifiles,md5;  	 
const
  supminkrnl=797; supmaxkrnl=970; 	// not used
  fmt_rfc3339='yyyy-mm-dd"T"hh:nn:ss';
  
  MinSingle=	Single	(1.5E-45);		MaxSingle=	Single	(3.4E38);
  MinDouble=	Double	(5.0E-324);		MaxDouble=	Double	(1.7E308);
  MinExtended=	Extended(1.9E-4932);	MaxExtended=Extended(1.1E4932);
  MinReal=		MinDouble;				MaxReal=	MaxDouble;
  
  eeprom_devadr_c=$50;	// EEPROM @ I2C-Adr 0x50 
  
  hdl_unvalid=-1;
  AN=true; AUS=false; AUF=true; ZU=false; LINKS=false; RECHTS=true;
  TestTimeOut_sec=60;	// 1min
  wdoc_path_c=			'/dev/watchdog';
  rpi_fw_dev=			'/dev/vcio';
  rpi_cpu_temp_dev_c=	'/sys/class/thermal/thermal_zone0/temp'; 
//http://makezine.com/2016/03/02/raspberry-pi-3-not-halt-catch-fire/
  RPI_TempAlarmCelsius_c=  85;	// 85'C according to spec (max. temp)  
  RPI_CTempWarn_c= 		0.906;	// 82'C rpi start to throttle@82Deg
  RPI_CTempCool_c=		0.588;	// factor of RPI_TempAlarmCelsius_c -> 85*0.58=50
  RPI_CTempHot_c=		0.953;	 
 
  LF      = #$0A; CR   = #$0D; STX      = #$02; ETX = #$03;	ESC=#27;
  Cntrl_Z = #$1A; BELL =   #7; EOL_char =   LF; HT  = #$09; // HT=TAB
  yes_c='TRUE,YES,1,JA,AN,EIN,HIGH,ON'; nein_c='FALSE,NO,0,NEIN,AUS,LOW,OFF';
  CompanyShortName='BASIS';
  DfltSect_c='DEFAULT'; HomeSect_c='HOME';
  UAgentDefault='Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:36.0) Gecko/20100101 Firefox/36.0';
//https://curl.haxx.se/docs/manpage.html
  CURLTimeOut_c= '300'; CURLPorts_c='49152-63000';
  CURLFTPDefaults_c='--retry 3 --retry-delay 5 --ftp-pasv --ftp-skip-pasv-ip --disable-epsv --connect-timeout '+CURLTimeOut_c+' --local-port '+CURLPorts_c;
  CURLSSLDefaults_c='-k --ssl --ssl-allow-beast';
  CURLpfext_c='.prog';
  cryptext_c= '.cpt';
  curlprogsync_ms_c=3000;		// > 9 
  {$IFDEF WINDOWS} 
    CRLF=CR+LF; dir_sep_c='\';	
	c_tmpdir='c:\tmp'; AppDataDir_c = 'c:\ProgramData\'+CompanyShortName;	
	LogDir_c=c_tmpdir;  c_cmddir='c:\cmd'; c_etcdir=c_tmpdir; 
  {$ELSE} 
    CRLF=LF; dir_sep_c='/'; 	
	c_tmpdir='/tmp'; AppDataDir_c = '/var/lib/'+CompanyShortName; 
	LogDir_c='/var/log'; c_cmddir='/usr/local/sbin'; c_etcdir = '/etc'; 
	dmtdir_c='/etc/service';  // Daemon-Tools directory
  {$ENDIF} 
  
// fbtft: framebuffer specific info. 
// needed for SPI OLED/TFT/LCD display (SSD1306 sainsmart18 ...) console 
// setterm --cursor off --clear all > /dev/tty1
// /usr/bin/fbi -d /dev/fb1 --noverbose -a /opt/splash.png
  tty_console_c=		'/dev/tty1';
  fbdev_c=				'/dev/fb1';
  fbcon_c=				'fbcon=map:10 fbcon=font:VGA8x8 logo.nologo';	// /dev/fb1 <-> /dev/tty1
(*  
/etc/modules-load.d/fbtft.conf
spi_bcm2835
fbtft_device

TFT-Tyoe: 1.8SPI 128x160 kompatibel zu sainsmart18 (evtl. auch ander displays zum setzen!!!!!)
/etc/modprobe.d/fbtft.conf
options fbtft_device name=sainsmart18 debug=3 rotate=90 speed=16000000

TFT-Tyoe: 0.91SPI 128x64 kompatibel zu SSD1306
options fbtft_device name=adafruit13m debug=3 speed=16000000 gpios=dc:9
*)
  
  sslcfgfile_c=AppDataDir_c+'/openssl.cnf';
  cert_dir_c=		'/etc/ssl';
  cert_key_dir_c=	cert_dir_c+'/private';					
  cert_crt_dir_c=	cert_dir_c+'/certs';
  ca_pem_c=			cert_crt_dir_c+'/Deutsche_Telekom_Root_CA_2.pem';	// default ca file
  
  cert0_key_c=		cert_key_dir_c+'/ssl-cert-snakeoil.key';	
  cert0_combined_c=	cert_key_dir_c+'/ssl-cert-snakeoil-combined.pem'; // e.g. for lighthttpd, shellinabox
  cert0_crtORpem_c=	cert_crt_dir_c+'/ssl-cert-snakeoil.pem';
  
  cert1_key_c=		cert_key_dir_c+'/server.key';
  cert1_combined_c=	cert_key_dir_c+'/server-combined.pem'; 
  cert1_crtORpem_c=	cert_crt_dir_c+'/server.crt';
  
  letsencryptdir_c=	'/etc/letsencrypt/live';
  
  LNX_ShadowFile=		'/etc/shadow';
  
  ifuap_c=				'ap0';
  ifeth_c=				'eth0';
  ifwlan_c=				'wlan0';
  ifwlan1_c=			'wlan1';
  ovpn_dev_c=			'tun0';
  noip_c=				'noIPAdr'; 
  noMAC_c=				'noMAC';
  unknown_c=			'unknown';
  exit_c=				'<exit>';
  none_c=				'<none>';
  usrbrk_c=				'usr break';
    
  hnamdflt_c=	'raspberrypi';
  EncDecPWD_c=	'rpi_hal$4712';		// default pwd, if no encrypt/decrypt pwd is supplied
  
  CRLF4HTTP=CR+LF; // for HTTP-Protocol we have to send 0d0a 
  ext_sep_c='.'; 
  sep_max_c=6;
  sep:array[0..sep_max_c] of char=(';',',','|','*','~','`','^');
     		   
  osc_freq_c			=  19200000; // OSC  (19.2Mhz ClkSrc=1)	
  pllc_freq_c			=1000000000; // PLLC (1000Mhz ClkSrc=5, changes with overclock settings) 
  plld_freq_c			= 500000000; // PLLD ( 500Mhz ClkSrc=6)
  HDMI_freq_c			= 216000000; // HDMI ( 216Mhz ClkSrc=7, auxiliary) 
  
  gpiomax_reg_c			=54; // max. gpio count (GPIO0-53) pls. see (BCM2709) 2012 Datasheet page 102ff 
  GPIO_PWM0	   			=18; // GPIO18 PWM0 	on Connector Pin12
  GPIO_PWM1				=19; // GPIO19 PWM1 	on Connector Pin35  (RPI2)
  GPIO_PWM0A0		   	=12; // GPIO12 PWM0 	on Connector Pin32  (RPI2)
  GPIO_PWM1A0			=13; // GPIO13 PWM1 	on Connector Pin33  (RPI2)
  GPIO_FRQ04_CLK0		= 4; // GPIO4  GPCLK0 	on Connector Pin7
  GPIO_FRQ05_CLK1		= 5; // GPIO5  GPCLK1 	on Connector Pin29  (reserved for system use)
  GPIO_FRQ06_CLK2		= 6; // GPIO6  GPCLK2 	on Connector Pin31
  GPIO_FRQ20_CLK0		=20; // GPIO20 GPCLK0 	on Connector Pin38  
  GPIO_FRQ21_CLK1		=21; // GPIO21 GPCLK1 	on Connector Pin40  (reserved for system use)
  GPIO_FRQ32_CLK0		=32; // GPIO32 GPCLK0	Compute module only
  GPIO_FRQ34_CLK0		=34; // GPIO34 GPCLK0	Compute module only
  GPIO_FRQ42_CLK1		=42; // GPIO42 GPCLK1	Compute module only (reserved for system use)
  GPIO_FRQ43_CLK2		=43; // GPIO43 GPCLK3	Compute module only 
  GPIO_FRQ44_CLK1		=44; // GPIO44 GPCLK1	Compute module only (reserved for system use)
  
  GPIO_path_c='/sys/class/gpio';
  mdl=9;
  wid1=12;
  gpiomax_map_idx_c=2;
  max_pins_c = 40;
//Map Pin-Nr on HW Header P1 to GPIO-Nr. (http://elinux.org/RPI_Low-level_peripherals)  
  UKN=-99; WRONGPIN=UKN-1; V5=-98; V33=-97; GND=-96; DNC=-95; IDSC=1; IDSD=0;
  GPIO_hdr_map_c:array[1..gpiomax_map_idx_c] of array[1..max_pins_c] of integer = //     !! <- Delta rev1 and rev2 	 									           --> Pins (27-40) only available on newer RPIs
//  							I2C		  I2C 																		   SPI		  SPI	
  (// HW-PIN           1    2    3    4    5     6     7     8     9    10   11   12   13   14    15   16    17   18    19   20    21  22    23    24   25    26   [27     28   29    30   31   32   33    34   35   36   37   38    39   40] }
   // Desc          3.3V   5V   SDA1  5V  SCL1  GND  1Wire  TxD   GND   RxD  11   12   13   GND   15   16  3.3V   18  MOSI  GND  MISO  22   SPI   SPI  GND   SPI  IDSD   IDSC   29   GND   31   32   33   GND   35   36   37   38   GND   40  }
    { rev1 GPIO } ( (V33),(V5),(UKN),(V5),( 1),(GND),(  4),( 14),(GND),(15),(17),(18),(21),(GND),(22),(23),(V33),(24),(10),(GND),( 9),(25),( 11),( 8),(GND),( 7),(IDSD),(IDSC),( 5),(GND),( 6),(12),(13),(GND),(19),(16),(26),(20),(GND),(21) ),
    { rev2 & B+ } ( (V33),(V5),(  2),(V5),( 3),(GND),(  4),( 14),(GND),(15),(17),(18),(27),(GND),(22),(23),(V33),(24),(10),(GND),( 9),(25),( 11),( 8),(GND),( 7),(IDSD),(IDSC),( 5),(GND),( 6),(12),(13),(GND),(19),(16),(26),(20),(GND),(21) )
  );
  
//Pin-Nr on HW Header P1; definitions for piggy-back board
  Int_Pin_on_RPI_Header=15; // =GPIO22 -> PIN Number on rpi HW Header P1  ref: http://elinux.org/RPI_Low-level_peripherals
  Ena_Pin_on_RPI_Header=22; // =GPIO25 -> RFM22_SD
  OOK_Pin_on_RPI_Header=11; // =GPIO17 -> RFM22_OOK
  IO1_Pin_on_RPI_Header=13; // =GPIO21/GPIO27 -> TLP434A OOK
  ITX_Pin_on_RPI_Header=12; // =GPIO18 -> IR TX
  IRX_Pin_on_RPI_Header=16; // =GPIO23 -> IR RX
  W1__Pin_on_RPI_Header=07; // =GPIO4  -> 1Wire BitBang
  Int_SPI_01_RPI_Header=18; // =GPIO24 -> Int Pin SPI1 on JP1 Pin5
 
//ARM Physical to VC IO Mapping  
  BCM2xxx_VCIO_ALIAS=	$7E000000;
//ARM Physical to VC Bus Mapping
  GPU_CACHED_BASE=		$40000000;
  GPU_UNCACHED_BASE=	$C0000000;
   
{ BCM2708: Physical addresses range from 0x20000000 to 0x20FFFFFF for peripherals. 
    The bus addresses for peripherals are set up to map onto the peripheral 
	bus address range starting at 0x7E000000. 
	Thus a peripheral advertised here at bus address 0x7Ennnnnn is available 
	at physical address 0x20nnnnnn. }
	
  PAGE_SIZE=			$1000;		// 4k
  BCM270x_PSIZ_Byte= 	$80000000-BCM2xxx_VCIO_ALIAS; // MemoryMap: Size of Peripherals. Docu Page 5  
  BCM270x_RegSizInByte= SizeOf(longword);
  BCM270x_RegMaxIdx= 	(BCM270x_PSIZ_Byte div BCM270x_RegSizInByte)-1; // Registers 0..RegMaxIdx
  BCM2708_PBASE= 		$20000000; 	// Peripheral Base in Bytes
  BCM2709_PBASE= 		$3F000000; 	// Peripheral Base in Bytes (RPI2B Processor) 
  
  STIM_BASE_OFS=    	$00003000; 	// Docu Page 172ff SystemTimer
  INTR_BASE_OFS=   		$0000B000;  // Docu Page 112ff 
  TIMR_BASE_OFS=   		$0000B000;  // Docu Page 196ff Timer ARM side
  MBX_BASE_OFS=			$0000B880;	// MailboxBaseAddr
  PADS_BASE_OFS=   		$00100000; 
  CLK_BASE_OFS=   		$00101000; 	// Docu Page 107ff
  GPIO_BASE_OFS=   		$00200000; 	// Docu Page  90ff GPIO contr. page start (1 page=4096Bytes) 
  UART_BASE_OFS=   		$00201000;	// Docu Page 177ff
  PCM_BASE_OFS=    		$00203000;	// Docu Page 125ff
  SPI0_BASE_OFS=   		$00204000;	// Docu Page 152ff
  PWM_BASE_OFS=   		$0020C000; 	// Docu Page 138ff
  BSC_BASE_OFS=    		$00214000;	// Docu Page 160ff
  AUX_BASE_OFS=   		$00215000;  // Docu Page   8ff
  BSC0_BASE_OFS=   		$00205000;	// Docu Page  28ff
  BSC1_BASE_OFS=   		$00804000;	// Docu Page  28ff
  BSC2_BASE_OFS=   		$00805000;	// Docu Page  28ff
  I2C0_BASE_OFS=		BSC0_BASE_OFS;
  I2C1_BASE_OFS=		BSC1_BASE_OFS;
  I2C2_BASE_OFS=		BSC2_BASE_OFS;
  EMMC_BASE_OFS=   		$00300000;	// Docu Page  66ff
  BCM2709_LP_OFS=		$01000000;	// $40000000 BCM2836 Quad-A7 Core Local PeripheralBase. Docu QA7-rev3.4

//0x 4000 0000
//Indexes		(each addresses 4 Bytes) 
  Q4LP_BASE			= BCM2709_LP_OFS div BCM270x_RegSizInByte;
  Q4LP_CTL			= Q4LP_BASE+ 0;	// Control register Docu QA7_rev3.4 Page 7ff
  Q4LP_CTIMPRE		= Q4LP_BASE+ 2;	// Core timer prescaler	
  Q4LP_GPUINTRTG	= Q4LP_BASE+ 3;	// GPU interrupts routing
  Q4LP_CoreTimAccLS = Q4LP_BASE+ 7;	// Core timer access LS 32 bits
  Q4LP_CoreTimAccMS = Q4LP_BASE+ 8;	// Core timer access MS 32 bits
  Q4LP_LOCINTRTG	= Q4LP_BASE+ 9;	// Local Interrupt 0 [1-7] routing
  Q4LP_LOCTIMCTL	= Q4LP_BASE+13;	// Local timer control & status
  Q4LP_Core0IntCtl	= Q4LP_BASE+16;	// Core0 timer Interrupt control
  Q4LP_Core0IrqSrc	= Q4LP_BASE+24;	// Core0 IRQ Source
  Q4LP_Core0FIQSrc	= Q4LP_BASE+28;	// Core0 FIQ Source
  Q4LP_Last			= Q4LP_BASE+63;	// max. of 64 registers (0..63)

//0x 7E10 0000	// https://de.scribd.com/doc/101830961/GPIO-Pads-Control2
  PADS_BASE			= PADS_BASE_OFS div BCM270x_RegSizInByte;
  PADS_GPIO00_27	= PADS_BASE+$0b;	// 0x7e10 002c PADS (GPIO  0-27)
  PADS_GPIO28_45	= PADS_BASE+$0c;	// 0x7e10 0030 PADS (GPIO 28-45)
  PADS_GPIO46_53	= PADS_BASE+$0d;	// 0x7e10 0034 PADS (GPIO 46-53)
  PADS_BASE_START	= PADS_GPIO00_27;
  PADS_BASE_LAST	= PADS_GPIO46_53;
  
//0x 7E20 0000  
  GPIO_BASE			= GPIO_BASE_OFS div BCM270x_RegSizInByte;
  GPFSEL			= GPIO_BASE+$00;
  GPSET				= GPIO_BASE+$07; // Register Index: set   bits which are 1 ignores bits which are 0 
  GPCLR				= GPIO_BASE+$0a; // Register Index: clear bits which are 1 ignores bits which are 0  
  GPLEV				= GPIO_BASE+$0d;
  GPEDS				= GPIO_BASE+$10; // Pin Event Detection 
  GPREN				= GPIO_BASE+$13; // Pin RisingEdge  Detection 
  GPFEN				= GPIO_BASE+$16; // Pin FallingEdge Detection 
  GPHEN				= GPIO_BASE+$19; // Pin High Detection 
  GPLEN				= GPIO_BASE+$1c; // Pin Low  Detection 
  GPAREN			= GPIO_BASE+$1f; // Pin Async. RisigngEdge Detection 
  GPAFEN			= GPIO_BASE+$22; // Pin Async. FallingEdge Detection 
  GPPUD				= GPIO_BASE+$25; // Pin Pull-up/down Enable 
  GPPUDCLK			= GPIO_BASE+$26; // Pin Pull-up/down Enable Clock 
  GPTEST			= GPIO_BASE+$29;
  GPIOONLYREAD		= GPLEV;		 // 2x 32Bit Register, which are ReadOnly
  GPIO_BASE_LAST	= GPTEST;

  TIMR_BASE			= (TIMR_BASE_OFS+$400) div BCM270x_RegSizInByte; // Docu Page 196 
  APMLOAD			= TIMR_BASE+0;// 0x00	
  APMVALUE			= TIMR_BASE+1;// 0x04
  APMCTL			= TIMR_BASE+2;// 0x08
  APMIRQCLRACK		= TIMR_BASE+3;// 0x0c	// reading gives always 0x544D5241
  APMRAWIRQ			= TIMR_BASE+4;// 0x10
  APMMaskedIRQ		= TIMR_BASE+5;// 0x14
  APMReload			= TIMR_BASE+6;// 0x18
  APMPreDivider		= TIMR_BASE+7;// 0x1c
  APMFreeRunCounter	= TIMR_BASE+8;// 0x20	// Offset 0x420
  INTR_BASE_LAST	= APMFreeRunCounter;
  TestREG			= APMIRQCLRACK;
  
  STIM_BASE			= STIM_BASE_OFS div BCM270x_RegSizInByte; // SystemTimer
  STIMCS			= STIM_BASE+$00;	//  0
  STIMCLO			= STIM_BASE+$01;	//  4
  STIMCHI			= STIM_BASE+$02;	//  8
  STIMC0			= STIM_BASE+$03;	// 12
  STIMC1			= STIM_BASE+$04;	// 16
  STIMC2			= STIM_BASE+$05;	// 20
  STIMC3			= STIM_BASE+$06;	// 24
  STIM_BASE_LAST	= STIMC3;
  
  I2C0_BASE			= I2C0_BASE_OFS div BCM270x_RegSizInByte;
  I2C0_C			= I2C0_BASE+$00;  //  0
  I2C0_S			= I2C0_BASE+$01;  //  4
  I2C0_DLEN			= I2C0_BASE+$02;  //  8
  I2C0_A			= I2C0_BASE+$03;  //  0x0c
  I2C0_FIFO			= I2C0_BASE+$04;  //  0x10
  I2C0_DIV			= I2C0_BASE+$05;  //  0x14
  I2C0_DEL			= I2C0_BASE+$06;  //  0x18
  I2C0_CLKT			= I2C0_BASE+$07;  //  0x1c
  I2C0_BASE_LAST	= I2C0_CLKT;
  
  I2C1_BASE			= I2C1_BASE_OFS div BCM270x_RegSizInByte;
  I2C1_C			= I2C1_BASE+$00;  //  0
  I2C1_S			= I2C1_BASE+$01;  //  4
  I2C1_DLEN			= I2C1_BASE+$02;  //  8
  I2C1_A			= I2C1_BASE+$03;  //  0x0c
  I2C1_FIFO			= I2C1_BASE+$04;  //  0x10
  I2C1_DIV			= I2C1_BASE+$05;  //  0x14
  I2C1_DEL			= I2C1_BASE+$06;  //  0x18
  I2C1_CLKT			= I2C1_BASE+$07;  //  0x1c
  I2C1_BASE_LAST	= I2C1_CLKT;
  
  I2C2_BASE			= I2C2_BASE_OFS div BCM270x_RegSizInByte;
  I2C2_C			= I2C2_BASE+$00;  //  0
  I2C2_S			= I2C2_BASE+$01;  //  4
  I2C2_DLEN			= I2C2_BASE+$02;  //  8
  I2C2_A			= I2C2_BASE+$03;  //  0x0c
  I2C2_FIFO			= I2C2_BASE+$04;  //  0x10
  I2C2_DIV			= I2C2_BASE+$05;  //  0x14
  I2C2_DEL			= I2C2_BASE+$06;  //  0x18
  I2C2_CLKT			= I2C2_BASE+$07;  //  0x1c
  I2C2_BASE_LAST	= I2C2_CLKT;
  
  SPI0_BASE			= SPI0_BASE_OFS div BCM270x_RegSizInByte;
  SPI0_CS 			= SPI0_BASE+$00; //  0
  SPI0_FIFO	  		= SPI0_BASE+$01; //  4
  SPI0_CLK	  		= SPI0_BASE+$02; //  8
  SPI0_DLEN	  		= SPI0_BASE+$03; //  0x0c
  SPI0_LTOH	  		= SPI0_BASE+$04; //  0x10
  SPI0_DC	  		= SPI0_BASE+$05; //  0x14
  SPI0_BASE_LAST	= SPI0_DC;
  
  MBX_BASE			= MBX_BASE_OFS div BCM270x_RegSizInByte;
  MBX_READ0			= MBX_BASE+$00;	//	0x00		Read data from VC to ARM
  MBX_PEEK0			= MBX_BASE+$04;	//	0x10
  MBX_SENDER0		= MBX_BASE+$05;	//	0x14
  MBX_STATUS0		= MBX_BASE+$06;	//	0x18		Status of VC to ARM
  MBX_CONFIG0		= MBX_BASE+$07;	//	0x1c
  MBX_WRITE1		= MBX_BASE+$08;	//	0x20		Write data from ARM to VC
  MBX_PEEK1			= MBX_BASE+$0c;	//	0x30
  MBX_SENDER1		= MBX_BASE+$0d;	//	0x34
  MBX_STATUS1		= MBX_BASE+$0e;	//	0x38
  MBX_CONFIG1		= MBX_BASE+$0f;	//	0x3c		
  
  PWM_BASE			= PWM_BASE_OFS div BCM270x_RegSizInByte;
  PWMCTL 			= PWM_BASE+$00;	//  0
  PWMSTA	  		= PWM_BASE+$01; //  4
  PWMDMAC	  		= PWM_BASE+$02; //  8
  PWM0RNG 	 		= PWM_BASE+$04; // 0x10
  PWM0DAT   		= PWM_BASE+$05; // 0x14
  PWM0FIF   		= PWM_BASE+$06; // 0x18
  PWM1RNG	  		= PWM_BASE+$08; // 0x20
  PWM1DAT   		= PWM_BASE+$09; // 0x24
  PWM_BASE_LAST		= PWM1DAT;
 
  GMGPxCTL_BASE		= CLK_BASE_OFS div BCM270x_RegSizInByte; // Manual Page 107ff
  GMGP0CTL			= GMGPxCTL_BASE+$1c;// 0x2010 1070
  GMGP0DIV			= GMGPxCTL_BASE+$1d;// 0x2010 1074
  GMGP1CTL			= GMGPxCTL_BASE+$1e;// 0x2010 1078
  GMGP1DIV			= GMGPxCTL_BASE+$1f;// 0x2010 107c
  GMGP2CTL			= GMGPxCTL_BASE+$20;// 0x2010 1080
  GMGP2DIV			= GMGPxCTL_BASE+$21;// 0x2010 1084
  GMGP_BASE_LAST	= GMGP2DIV;

  PWMCLK_BASE		= CLK_BASE_OFS div BCM270x_RegSizInByte;	// Manual Page 107ff
  PWMCLKCTL 		= PWMCLK_BASE+$28;  //160 0xA0
  PWMCLKDIV  		= PWMCLK_BASE+$29;  //164 0xA4
  PWMCLK_BASE_LAST	= PWMCLKDIV;
  
  PWM_MS_MODE		= $80;
  PWM_USEFIFO		= $10;
  PWM_POLARITY		= $08;
  PWM_RPTL			= $04;
  PWM_SERIALIZER	= $02;
  
  PWM1_MS_MODE    	= $8000;  // Run in MS mode
  PWM1_USEFIFO    	= $2000;  // Data from FIFO
  PWM1_REVPOLAR   	= $1000;  // Reverse polarity
  PWM1_OFFSTATE   	= $0800;  // Ouput Off state
  PWM1_REPEATFF   	= $0400;  // Repeat last value if FIFO empty
  PWM1_SERIAL     	= $0200;  // Run in serial mode
  PWM1_ENABLE     	= $0100;  // Channel Enable
  
  PWM0_MS_MODE    	= $0080;  // Run in MS mode
  PWM0_USEFIFO    	= $0020;  // Data from FIFO
  PWM0_REVPOLAR   	= $0010;  // Reverse polarity
  PWM0_OFFSTATE   	= $0008;  // Ouput Off state
  PWM0_REPEATFF   	= $0004;  // Repeat last value if FIFO empty
  PWM0_SERIAL     	= $0002;  // Run in serial mode
  PWM0_ENABLE     	= $0001;  // Channel Enable
  
  PWM_DIVImax		= $0fff;  // 12Bit
  PWM_DIVImin		= 32;  	  // default
  
  BCM_PWD			= $5A000000;
  
  ENC_cnt			= 2;	  // Encoder Count
  ENC_SyncTime_c	= 12;	  // max. interval /sync. response time of device in msec and switch debounce time
  ENC_SwRepeatTime_c= 1000;	  // if switch is pressed 1sec, treat as repeated keystroke 
  ENC_sleeptime_def	= 50;
  ENC_SwitchShutDown= 3000;	  // Switch pressed 3sec signals ShutDown 
  
  TRIG_SyncTime_c	= 10;
    
  SERVO_FRQ=  50;								  // Servo SG90 frequency (Hz) for PWM
  SERVO_Speed=100; 						  	      // Datasheet Value:0.1s/60degree
  SRVOMINANG=-90; SRVOMIDANG=0;   SRVOMAXANG= 90; // Servo SG90 Datasheet Values (Angles in degree)
//SRVOMINDC=1000; SRVOMIDDC=1500; SRVOMAXDC=2000; // Servo SG90 Datasheet Values (us)
  SRVOMINDC= 600; SRVOMIDDC=1600; SRVOMAXDC=2600; // Servo SG90 Values found experimentally (us)
  
//LOG_All =1; LOG_DEBUG = 2; LOG_INFO =  10; Log_NOTICE = 20; Log_WARNING = 50; Log_ERROR = 100; Log_URGENT = 250; LOG_NONE = 254;   

  I2C_COMBINED_path_c= '/sys/module/i2c_bcm2708/parameters/combined';
//source: http://I2C-tools.sourcearchive.com/documentation/3.0.3-5/I2C-dev_8h_source.html 
  I2C_path_c		 = '/dev/i2c-';
  I2C_max_bus        = 1;
  I2C_unvalid_addr	 = $ff;
  I2C_UseNoReg		 = $ffff;  {  use this as Read/Write register, 
							      if I2C device has no registers (RD/WR only one value)
							      like the pressure sensor HDI M500 }
  I2C_M_TEN          = $0010;  // we have a ten bit chip address 
  I2C_M_WR			 = $0000;
  I2C_M_RD           = $0001;
  I2C_M_NOSTART      = $4000;
  I2C_M_REV_DIR_ADDR = $2000;
  I2C_M_IGNORE_NAK   = $1000;
  I2C_M_NO_RD_ACK    = $0800;
  I2C_M_RECV_LEN     = $0400;  // length will be first received byte
 
  I2C_RETRIES        = $0701; // number of times a device address should be polled when not acknowledging
  I2C_TIMEOUT        = $0702; // set timeout - call with int            
  I2C_SLAVE          = $0703; // Change slave address                   
                              // Attn.: Slave address is 7 or 10 bits   
  I2C_SLAVE_FORCE    = $0706; {  Change slave address                   
                                 Attn.: Slave address is 7 or 10 bits   
                                 This changes the address, even if it 
                                 is already taken! }
  I2C_TENBIT         = $0704; // 0 for 7 bit addrs, != 0 for 10 bit     

  I2C_FUNCS          = $0705; // Get the adapter functionality          
  I2C_RDWR           = $0707; // Combined R/W transfer (one stop only)
  I2C_PEC            = $0708; // != 0 for SMBus PEC                     
  I2C_SMBUS          = $0720; // SMBus-level access                     
    
  I2C_CTRL_REG		 =  0; 	  // Register Indexes
  I2C_STATUS_REG	 =  1;
  I2C_DLEN_REG		 =  2;
  I2C_A_REG			 =  3;
  I2C_FIFO_REG		 =  4;
  I2C_DIV_REG		 =  5;
  I2C_DEL_REG		 =  6;
  I2C_CLKT_REG		 =  7;
  
  I2C_RDWR_IOCTL_MAX_MSGS		  = 42;
  
//to determine what functionality is present 
  I2C_FUNC_I2C                    = $00000001;
  I2C_FUNC_10BIT_ADDR             = $00000002;
  I2C_FUNC_PROTOCOL_MANGLING      = $00000004; // I2C_M_[REV_DIR_ADDR,NOSTART,..] 
  I2C_FUNC_SMBUS_PEC              = $00000008;
  I2C_FUNC_NOSTART				  = $00000010; // I2C_M_NOSTART
  I2C_FUNC_SLAVE				  = $00000020;
  I2C_FUNC_SMBUS_BLOCK_PROC_CALL  = $00008000; // SMBus 2.0 
  I2C_FUNC_SMBUS_QUICK            = $00010000; 
  I2C_FUNC_SMBUS_READ_BYTE        = $00020000; 
  I2C_FUNC_SMBUS_WRITE_BYTE       = $00040000; 
  I2C_FUNC_SMBUS_READ_BYTE_DATA   = $00080000; 
  I2C_FUNC_SMBUS_WRITE_BYTE_DATA  = $00100000; 
  I2C_FUNC_SMBUS_READ_WORD_DATA   = $00200000; 
  I2C_FUNC_SMBUS_WRITE_WORD_DATA  = $00400000; 
  I2C_FUNC_SMBUS_PROC_CALL        = $00800000; 
  I2C_FUNC_SMBUS_READ_BLOCK_DATA  = $01000000; 
  I2C_FUNC_SMBUS_WRITE_BLOCK_DATA = $02000000; 
  I2C_FUNC_SMBUS_READ_I2C_BLOCK   = $04000000; // I2C-like block xfer  
  I2C_FUNC_SMBUS_WRITE_I2C_BLOCK  = $08000000; // w/ 1-byte reg. addr.  
  I2C_FUNC_SMBUS_BYTE             = I2C_FUNC_SMBUS_READ_BYTE       or I2C_FUNC_SMBUS_WRITE_BYTE;
  I2C_FUNC_SMBUS_BYTE_DATA        = I2C_FUNC_SMBUS_READ_BYTE_DATA  or I2C_FUNC_SMBUS_WRITE_BYTE_DATA;
  I2C_FUNC_SMBUS_WORD_DATA        = I2C_FUNC_SMBUS_READ_WORD_DATA  or I2C_FUNC_SMBUS_WRITE_WORD_DATA;
  I2C_FUNC_SMBUS_BLOCK_DATA       = I2C_FUNC_SMBUS_READ_BLOCK_DATA or I2C_FUNC_SMBUS_WRITE_BLOCK_DATA;
  I2C_FUNC_SMBUS_I2C_BLOCK        = I2C_FUNC_SMBUS_READ_I2C_BLOCK  or I2C_FUNC_SMBUS_WRITE_I2C_BLOCK;  

  RPI_I2C_general_purpose_bus_c=1;  
  c_max_Buffer   	= $ff-1;  // was 128 // was 024 

  SPI_IOC_MAGIC     = 'k';
  
  SPI_CPHA			= $01;
  SPI_CPOL			= $02;
  SPI_MODE_0		= $00;
  SPI_MODE_1		= SPI_CPHA;
  SPI_MODE_2		= SPI_CPOL;
  SPI_MODE_3		= SPI_CPOL or SPI_CPHA;
  SPI_CS_HIGH		= $04;
  SPI_LSB_FIRST		= $08;
  SPI_3WIRE			= $10;
  SPI_LOOP			= $20;
  SPI_NO_CS			= $40;
  SPI_READY			= $80;
  SPI_TX_DUAL		= $100;
  SPI_TX_QUAD		= $200;
  SPI_RX_DUAL		= $400;
  SPI_RX_QUAD		= $800;
  
  spi_path_c		= '/dev/spidev';
  spi_max_bus    	= 0;
  spi_max_dev	 	= 1; 
  SPI_BUF_SIZE_c 	= c_max_Buffer;	// 255; // was 64;
  SPI_unvalid_addr	=$ffff;
  SPI_Speed_c		=500000; 
    
  _IOC_NONE   	 	=$00; _IOC_WRITE 	 =$01; _IOC_READ	  =$02;
  _IOC_NRBITS    	=  8; _IOC_TYPEBITS  =  8; _IOC_SIZEBITS  = 14; _IOC_DIRBITS  =  2;
  _IOC_NRSHIFT   	=  0; 
  _IOC_TYPESHIFT 	= (_IOC_NRSHIFT+  _IOC_NRBITS); 
  _IOC_SIZESHIFT 	= (_IOC_TYPESHIFT+_IOC_TYPEBITS);
  _IOC_DIRSHIFT  	= (_IOC_SIZESHIFT+_IOC_SIZEBITS);
  
  ERR_MAXCNT		=   5;
  ERR_AutoResetMSec	=2000;	// AutoReset of Errors in msec. 0=noReset
  NO_ERRHNDL		=  -1;
  NO_TEST        	= NO_ERRHNDL;

  RTC_RD_TIME 		= $40247009; 	//-2145095671;
  RTC_SET_TIME 		= $4024700A;	// 1076129802;
  
//consts for rpi fw mbx access (/dev/vcio)
//source: https://github.com/raspberrypi/linux/blob/rpi-4.9.y/include/soc/bcm2835/raspberrypi-firmware.h
// 14 Nov 2017
//TAG_property_stati
  TAG_STATUS_REQUEST=							0;
  TAG_STATUS_SUCCESS=							$80000000;
  TAG_STATUS_ERROR=								$80000001;

//TAG_property_tags  
  TAG_PROPERTY_END=								0;
  TAG_GET_FIRMWARE_REVISION=					$00000001;

  TAG_SET_CURSOR_INFO=							$00008010;
  TAG_SET_CURSOR_STATE=							$00008011;

  TAG_GET_BOARD_MODEL=							$00010001;
  TAG_GET_BOARD_REVISION=						$00010002;
  TAG_GET_BOARD_MAC_ADDRESS=					$00010003;
  TAG_GET_BOARD_SERIAL=							$00010004;
  TAG_GET_ARM_MEMORY=							$00010005;
  TAG_GET_VC_MEMORY=							$00010006;
  TAG_GET_CLOCKS=								$00010007;
  TAG_GET_POWER_STATE=							$00020001;
  TAG_GET_TIMING=								$00020002;
  TAG_SET_POWER_STATE=							$00028001;
  TAG_GET_CLOCK_STATE=							$00030001;
  TAG_GET_CLOCK_RATE=							$00030002;
  TAG_GET_VOLTAGE=								$00030003;
  TAG_GET_MAX_CLOCK_RATE=						$00030004;
  TAG_GET_MAX_VOLTAGE=							$00030005;
  TAG_GET_TEMPERATURE=							$00030006;
  TAG_GET_MIN_CLOCK_RATE=						$00030007;
  TAG_GET_MIN_VOLTAGE=							$00030008;
  TAG_GET_TURBO=								$00030009;
  TAG_GET_MAX_TEMPERATURE=						$0003000a;
  TAG_GET_STC=									$0003000b;
  TAG_ALLOCATE_MEMORY=							$0003000c;
  TAG_LOCK_MEMORY=								$0003000d;
  TAG_UNLOCK_MEMORY=							$0003000e;
  TAG_RELEASE_MEMORY=							$0003000f;
  TAG_EXECUTE_CODE=								$00030010;
  TAG_EXECUTE_QPU=								$00030011;
  TAG_SET_ENABLE_QPU=							$00030012;
  TAG_GET_DISPMANX_RESOURCE_MEM_HANDLE=			$00030014;
  TAG_GET_EDID_BLOCK=							$00030020;
  TAG_GET_CUSTOMER_OTP=							$00030021;
  TAG_GET_DOMAIN_STATE=							$00030030;
  TAG_SET_CLOCK_STATE=							$00038001;
  TAG_SET_CLOCK_RATE=							$00038002;
  TAG_SET_VOLTAGE=								$00038003;
  TAG_SET_TURBO=								$00038009;
  TAG_SET_CUSTOMER_OTP=							$00038021;
  TAG_SET_DOMAIN_STATE=							$00038030;
  TAG_GET_GPIO_STATE=							$00030041;
  TAG_SET_GPIO_STATE=							$00038041;
  TAG_SET_SDHOST_CLOCK=							$00038042;
  TAG_GET_GPIO_CONFIG=							$00030043;
  TAG_SET_GPIO_CONFIG=							$00038043;
  TAG_GET_PERIPH_REG=							$00030045;
  TAG_SET_PERIPH_REG=							$00038045;

//* Dispmanx TAGS */
  TAG_FRAMEBUFFER_ALLOCATE=						$00040001;
  TAG_FRAMEBUFFER_BLANK=						$00040002;
  TAG_FRAMEBUFFER_GET_PHYSICAL_WIDTH_HEIGHT=	$00040003;
  TAG_FRAMEBUFFER_GET_VIRTUAL_WIDTH_HEIGHT=		$00040004;
  TAG_FRAMEBUFFER_GET_DEPTH=					$00040005;
  TAG_FRAMEBUFFER_GET_PIXEL_ORDER=				$00040006;
  TAG_FRAMEBUFFER_GET_ALPHA_MODE=				$00040007;
  TAG_FRAMEBUFFER_GET_PITCH=					$00040008;
  TAG_FRAMEBUFFER_GET_VIRTUAL_OFFSET=			$00040009;
  TAG_FRAMEBUFFER_GET_OVERSCAN=					$0004000a;
  TAG_FRAMEBUFFER_GET_PALETTE=					$0004000b;
  TAG_FRAMEBUFFER_GET_TOUCHBUF=					$0004000f;
  TAG_FRAMEBUFFER_GET_GPIOVIRTBUF=				$00040010;
  TAG_FRAMEBUFFER_RELEASE=						$00048001;
  TAG_FRAMEBUFFER_TEST_PHYSICAL_WIDTH_HEIGHT=	$00044003;
  TAG_FRAMEBUFFER_TEST_VIRTUAL_WIDTH_HEIGHT=	$00044004;
  TAG_FRAMEBUFFER_TEST_DEPTH=					$00044005;
  TAG_FRAMEBUFFER_TEST_PIXEL_ORDER=				$00044006;
  TAG_FRAMEBUFFER_TEST_ALPHA_MODE=				$00044007;
  TAG_FRAMEBUFFER_TEST_VIRTUAL_OFFSET=			$00044009;
  TAG_FRAMEBUFFER_TEST_OVERSCAN=				$0004400a;
  TAG_FRAMEBUFFER_TEST_PALETTE=					$0004400b;
  TAG_FRAMEBUFFER_TEST_VSYNC=					$0004400e;
  TAG_FRAMEBUFFER_SET_PHYSICAL_WIDTH_HEIGHT=	$00048003;
  TAG_FRAMEBUFFER_SET_VIRTUAL_WIDTH_HEIGHT=		$00048004;
  TAG_FRAMEBUFFER_SET_DEPTH=					$00048005;
  TAG_FRAMEBUFFER_SET_PIXEL_ORDER=				$00048006;
  TAG_FRAMEBUFFER_SET_ALPHA_MODE=				$00048007;
  TAG_FRAMEBUFFER_SET_VIRTUAL_OFFSET=			$00048009;
  TAG_FRAMEBUFFER_SET_OVERSCAN=					$0004800a;
  TAG_FRAMEBUFFER_SET_PALETTE=					$0004800b;
  TAG_FRAMEBUFFER_SET_TOUCHBUF=					$0004801f;
  TAG_FRAMEBUFFER_SET_GPIOVIRTBUF=				$00048020;
  TAG_FRAMEBUFFER_SET_VSYNC=					$0004800e;
  TAG_FRAMEBUFFER_SET_BACKLIGHT=				$0004800f;

  TAG_VCHIQ_INIT=								$00048010;

  TAG_GET_COMMAND_LINE=							$00050001;
  TAG_GET_DMA_CHANNELS=							$00060001;
  
  MB_CHANNEL_ERROR=	 $FEEDDEAD;	
  MB_CHANNEL_SUCCESS=$80000000;
  MB_FULL=			 $80000000;
  MB_LEVEL=			 $400000FF;
  MB_EMPTY=			 $40000000;	// Mailbox Status Register: Mailbox Empty
  MB_CHANNEL_POWER= 	$00;	// Mailbox Channel 0: Power Management Interface 
  MB_CHANNEL_FB=		$01;	// Mailbox Channel 1: Frame Buffer
  MB_CHANNEL_VUART=		$02;	// Mailbox Channel 2: Virtual UART
  MB_CHANNEL_VCHIQ=		$03;	// Mailbox Channel 3: VCHIQ Interface
  MB_CHANNEL_LEDS=		$04;	// Mailbox Channel 4: LEDs Interface
  MB_CHANNEL_BUTTONS=	$05;	// Mailbox Channel 5: Buttons Interface
  MB_CHANNEL_TOUCH=		$06;	// Mailbox Channel 6: Touchscreen Interface
  MB_CHANNEL_COUNT=		$07;	// Mailbox Channel 7: Counter
  MB_CHANNEL_TAGS=		$08;	// Mailbox Channel 8: Tags (ARM to VC)
  MB_CHANNEL_GPU=		$09;	// Mailbox Channel 9: GPU (VC to ARM)
     
//flags for watchdog     
  WDIOF_OVERHEAT=		$0001;	// Reset due to CPU overheat
  WDIOF_FANFAULT=		$0002;	// Fan failed
  WDIOF_EXTERN1=		$0004;	// External relay 1
  WDIOF_EXTERN2=		$0008;	// External relay 2
  WDIOF_POWERUNDER=		$0010;	// Power bad/power fault
  WDIOF_CARDRESET=		$0020;	// Card previously reset the CPU
  WDIOF_POWEROVER=		$0040;	// Power over voltage
  WDIOF_SETTIMEOUT=		$0080;	// Set timeout (in seconds)
  WDIOF_MAGICCLOSE=		$0100;	// Supports magic close char
  WDIOF_PRETIMEOUT=		$0200;	// Pretimeout (in seconds), get/set
  WDIOF_ALARMONLY=		$0400;	// Watchdog triggers a management or other external alarm not a reboot
  WDIOF_KEEPALIVEPING=	$8000;	// Keep alive ping reply	

//consts for PseudoTerminal IO (/dev/ptmx)
  Terminal_MaxBuf = 1024; 
  NCCS 		= 32;
  
  TCSANOW 	= 0; 			// make change immediate 
  TCSADRAIN = 1; 			// drain output, then change 
  TCSAFLUSH = 2; 			// drain output, flush input 
  TCSASOFT 	= $10; 			// flag - don't alter h.w. state 
  
  ECHOKE 	= $1; 			// visual erase for line kill 
  ECHOE 	= $2; 			// visually erase chars 
  ECHOK 	= $4; 			// echo NL after line kill 
  ECHO 		= $8; 			// enable echoing 
  ECHONL 	= $10; 			// echo NL even if ECHO is off 
  ECHOPRT 	= $20; 			// visual erase mode for hardcopy 
  ECHOCTL 	= $40; 			// echo control chars as ^(Char) 
  ISIG 		= $80; 			// enable signals INTR, QUIT, [D]SUSP 
  ICANON 	= $100; 		// canonicalize input lines 
  ALTWERASE = $200; 		// use alternate WERASE algorithm 
  IEXTEN 	= $400; 		// enable DISCARD and LNEXT 
  EXTPROC 	= $800; 		// external processing 
  TOSTOP 	= $400000; 		// stop background jobs from output 
  FLUSHO 	= $800000; 		// output being flushed (state) 
  NOKERNINFO= $2000000; 	// no kernel output from VSTATUS 
  PENDIN 	= $20000000; 	// XXX retype pending input (state) 
  NOFLSH 	= $80000000;	// don't flush after interrupt 
  
  RPI_hal_dscl=	20;
  
  CLOCK_REALTIME=0; 		// Taken from linux/time.h // Posix timers
  
  CertPublic=1; CertPrivKey=2; CertCA=3; CertCombined=4;
  CertPackRPIMaint=0; CertPackSnakeOil=1; CertPackServer=2; CertPackLetsEncrypt=3; CertPackLast=CertPackLetsEncrypt;
  
  iKp=0; iKi=1; iKd=2;		// arr-indexes for Kp,Ki,Kd
  PID_AVGminNum_c=2; PID_AVGmaxNum_c=50; PID_epsilon_c=0.000001; 
  PID_nk8=8;		 PID_timadj_c=0.000001; // usec sensor data
  PID_loctusec=4; 	 PID_locsollval=5; 	 PID_locistval=6; 	// csv field locations
  PID_twiddle_tolerance=0.00001;		 PID_twiddle_saveattol=PID_twiddle_tolerance*100;
  PID_twiddle_tolNOTsav=0;	 
  PID_nk15=15;
  
  IP_infomax_c=3;
  oldvalcnt_c= 3;
    
type
  E_rpi_hal_Exception= class(Exception);
  t_ErrorLevel=   (	LOG_NHdr,LOG_WHITE,LOG_BLACK,LOG_BLUE,LOG_GREEN,LOG_LHTGRN,LOG_YELLOW,LOG_ORANGE,LOG_RED,
  					LOG_All,LOG_DEBUG,LOG_INFO,LOG_NOTICE,LOG_WARNING,LOG_ERROR,LOG_URGENT,LOG_NONE,LOG_NONE2); 
//t_port_flags order is important, do not change. Ord(t_port_flags) will be used to set ALT-Bits in GPFSELx Registers.
// ORD:				   0,     1,   2,   3,   4,   5,   6,   7,    8,    9      10
  t_port_flags  = (	INPUT,OUTPUT,ALT5,ALT4,ALT0,ALT1,ALT2,ALT3,PWMHW,PWMSW,control,
					FRQHW,Simulation,PullUP,PullDOWN,(*PullEnable,*)RisingEDGE,FallingEDGE,
					DS2mA,DS4mA,DS6mA,DS8mA,DS10mA,DS12mA,DS14mA,DS16mA,noPADhyst,noPADslew,
					ReversePOLARITY,InitialHIGH,WRthrough,IOCheck,UseCSec,I2C,
					Bit5,Bit6,Bit7,Bit8,StopBit1,StopBit1H,StopBit2,HShw,HSsw,
					ParityNONE,ParityODD,ParityEVEN,ParityMark,ParitySpace,withSTTY,
					TTYstartCursor,TTYstopCursor,TTYclearScreen); 
					
  s_port_flags  = set of t_port_flags;
  t_initpart	= (	InitHaltOnError,InitGPIO, (* InitGPIOonly,*) InitRPIfw,InitI2C,InitSPI,
  					InitCreateScript,InitOnExitShowRuntime,StartShutDownWatcher,InitWDOG,InitWDOGnoThread,
  					InstSignalHandler,UPDAuthDBDateTime,InitCertSnakeOil,InitCertServer,InitCertLetsEncrypt);
  s_initpart  	= set of t_initpart;
  t_IOBusType	= (	UnknDev,I2CDev,SPIDev);
  t_PowerSwitch	= ( ELRO,Sartano,Nexa,Intertechno,FS20);
  t_rpimaintflags=(	UseENCrypt,UpdExec,UpdPKGGet,UpdPKGcopy,UseDECrypt,UpdPKGInst,UpdPKGInstV,
  					UpdUpld,UpdDwnld,UpdProtoHTTP,UpdProtoRAW,UAgent,UpdNoRedoRequest,
  					UpdNOP,UpdSSL,UpdVerbose,UpdForce,UpdUpdate,UpdNoProgressBar,UpdLogAppend,UpdNoFTPDefaults, //UpdSUDO,
  					UpdErrVerbose,UpdNoCreateDir,UpdNewerOnly,UpdCleanUP,
  					UpdNoWDOGprevent,UpdNoZIP,UpdFollowLink,UpdVerify,UpdDBG1,UpdDBG2,UpdnoMD5Chk,
  					UPDStop,UPDDisable,UPDEnable,UPDStart,UPDReStart,UpdShowThInfo,SysV,Systemd,
  					WDOG_Close,WDOG_Retrig,WDOG_GTO,WDOG_STO,WDOG_BSTAT,WDOG_GSup,WDOG_Pause,WDOG_Resume);  
  s_rpimaintflags=set of t_rpimaintflags;
  
  t_Manu_flag=	  (	unknownManufacturer,Bosch,HDI,AMS,HTD,MCP,IDT);
  
  t_BIOS_Flags=	  (	BIOS_secret,BIOS_noOVR,BIOS_DoESC,BIOS_UnESC,BIOS_crypt,
  					 BIOS_bool,BIOS_int,BIOS_uint,BIOS_float,BIOS_NonZero,BIOS_tstmp,BIOS_PrefDflt,
  					 BIOS_1byte,BIOS_2byte,BIOS_4byte,BIOS_lon,BIOS_lat,
  					 BIOS_trim1,BIOS_trim2,BIOS_trim3,BIOS_trim4,BIOS_trim5,BIOS_Printable);
  s_BIOS_Flags=		set of t_BIOS_Flags;
  
  Cert_Type_t=	  (	CT_rsa,CT_x509,CT_ssl,CT_serial,CT_modulus,CT_modmd5,CT_md5,CT_sha1,CT_sha256,CT_sha512,CT_combined,CT_Path);
  
  MSG_Type_t=	  (	noIDaddmsg,dashmsg,pmsg,usrmsg,maintmsg,curlprogmsg);
  
  t_MemoryMapPtr= ^t_MemoryMap;
  t_MemoryMap	= array[0..BCM270x_RegMaxIdx] of longword; // for 32 Bit access 
  buftype 		= array[0..c_max_Buffer-1] of byte;
  
  cint=longint; cuint=longword; cuint64=qword;
  Pclockid_t=^clockid_t; clockid_t=longint;
  
  t_CLOption = record Name,Value:string; end;
  t_CLOptions= array of t_CLOption;
  
  TProcedureNoArgCall=	procedure;
  TProcedureOneArgCall=	procedure(i:integer);
  TFunctionOneArgCall=	function (i:integer):integer;
  TcFunctionOneArgCall=	function (i:cint):cint;
  TThFunctionOneArgCall=function (ptr:pointer):ptrint;
  TFunctionThreeArgCall=function (lvl:t_ErrorLevel; msgtype:MSG_Type_t; msg:string):longint;
  
  STAT_struct_aold_t = record
	_val:		real;
	_valtimd:	int64;	
  end;
  STAT_struct_t = record
    arr_siz:	longint;
	tim_avg,
	dif_val_pms,
	old_val,
	val_avg,
	old_avg,
	ist_val	: 	 real;
	old_val_cnt: integer;
	aold:		 array[-1..(oldvalcnt_c-1)] of STAT_struct_aold_t; // -1: last avg
  end;
  
  isr_t = record
    devnum					: byte;
    enter_isr_routine,
	gpio,fd 				: longint;
	func_ptr 				: TFunctionOneArgCall;
	ThreadId				: TThreadID;
	ThreadPrio,
	flag,
	rslt 					: integer;
	rising_edge,
    int_enable 				: boolean; // if INT occures, INT Routine will be started or not 
	int_cnt,
    int_cnt_raw				: longword;
	enter_isr_time			: TDateTime;
	last_isr_servicetime	: int64;
  end;
    
  Thread_Ctrl_ptr= ^Thread_Ctrl_t;
  Thread_Ctrl_t=record	 
	ThreadID:		TThreadID; //PtrUInt; 
	ThreadRunning,
	TermThread:		boolean;
	ThreadFunc:		TThFunctionOneArgCall;
	ThreadTimeOut:	TDateTime;
	ThreadInfo,
	ThreadCmdStr,
	ThreadRetStr:	string;
	ThreadRetCode:	integer;
	ThreadProgressOld,
	ThreadProgress:	integer;
	UsrData:		array[0..4] of longword;
	ThreadPara:		array[0..4] of integer;
	ThreadParaStr:	array[0..4] of string;
  end;
  
  TL_prot_t=record
    TL_CS:TRTLCriticalSection;
    TL:TStringList;
    TL_modified:boolean;
    ThCtl:Thread_Ctrl_t; 
  end;
  
  ERR_MGMT_t = record
    addr:word;
	RDerr,WRerr,CMDerr,MAXerr,AutoReset_ms:longword;
	TSok,TSokOld,TSerr,TSerrOld:TDateTime;
	desc:string[RPI_hal_dscl];
  end;
  
  watchdog_info_t = record
	options,						// Options the card/driver supports
	firmware_version:	longword;	// Firmware version of the card
	identity: array[0..31] of byte;	// Identity of the board
  end;
				
  watchdog_struct_t = record
  	NextTrigTime,
  	WDOGFire:	TDateTime;
  	RetrigAsync:boolean;
  	Hndl,
  	retival_msec,
  	LastBootStat,
  	ival_sec:	longint;
    info:		watchdog_info_t;
    devpath:	string;
    ThreadCtrl:	Thread_Ctrl_t;
  end;

  HAT_Struct_t = record
    uuid,vendor,product,snr:string;
    product_id,product_ver:longword;
    available,overwrite:boolean;
  end;
  
  RPI_Temps_t=record
    TempIdx:	longint;				// points to max temp
  	TempMax:	real;
    Temp:		array[1..2] of real;	// CPU GPU Temp
    TempLvl:	array[1..2] of t_ErrorLevel;
    TempUnit:	array[1..2] of string;	// 'C &#x2103;
    TempInfo:	string;
  end;
  
  RPI_FW_API_t = record
	hndl:longint;
  end;
  
  RPI_MBX_tag_t = packed record
	tag_id:		longword;
	buffer_size:longword;
	data_size:	longword;
	dev_id:		longword;
	val:		longword;
  end;
  
  RPI_MBX_msgPTR_t= ^RPI_MBX_msg_t;
  RPI_MBX_msg_t = packed record
	msg_size:	longword;
	request_code:longword;
//	tag:		RPI_MBX_tag_t;
	tag_id:		longword;
	buffer_size:longword;
	data_size:	longword;
	dev_id:		longword;
	val:		longword;
	end_tag:	longword;
  end;
  
  rtc_time_t = record
    tm_sec,tm_min,tm_hour,tm_mday,tm_mon,tm_year,tm_wday,tm_yday,tm_isdst:longint;
  end;
  
  HW_Usage_t = record
  	usecnt,usetimesec:longword;
  	dat:TDateTime;
  end;
  
  HW_DevicePresent_t = record
    hndl:integer;
    DevType:t_IOBusType;
    present:boolean;
    BusNum,HWAddr:integer;
    descr:string[RPI_hal_dscl];
    data:string;
  end;
  
  I2C_Bus_Info_t = record
    I2C_CS 			: TRTLCriticalSection;
    I2C_useCS		: boolean;
	I2C_funcs,
	I2C_speed		: longword;
  end;
  
  I2C_databuf_ptr = ^I2C_databuf_t;
  I2C_databuf_t = record
	buf: 	string[c_max_Buffer];
	hdl: 	cint;
  end;
  
  I2C_msg_ptr = ^I2C_msg_t;
  I2C_msg_t = record
    addr:	word;
	flags:	word;
	len:	word;
	bptr:	I2C_databuf_ptr;
  end;
  
  I2C_rdwr_ioctl_data_t = record
    msgs:	I2C_msg_ptr;
	nmsgs:	longword;
  end;
  
  I2C_cmd_t=string[8];  
  I2C_rdwr_zip_msg_t = record
    msgset:	I2C_rdwr_ioctl_data_t;
	iomsgs:	array[0..1] of I2C_msg_t;
    zipbuf: I2C_cmd_t;  
  end;
  
  I2C_rdwr_zip_data_t = record
	hdl: 	cint;
	msgidx,
	busno,
	datlen:	longword;
	msgset:	I2C_rdwr_ioctl_data_t;
    iomsgs:	array[0..(I2C_RDWR_IOCTL_MAX_MSGS-1)] of I2C_msg_t;
  end;
  
  PWM_struct_t = record
  	pwm_mode		: byte;
	pwm_sigalt		: boolean;
	pwm_dutycycle_us,
	pwm_restcycle_us,
	pwm_period_us,
	pwm_period_ms,
	pwm_dutyrange,
	pwm_value		: longword;	
	pwm_dtycycl,				// 0-1 // 0%-100%
	pwm_freq_hz		: real;
  end;
  
  GPIO_ptr	   = ^GPIO_struct_t;
  GPIO_struct_t = record
    description		: string[RPI_hal_dscl];
    gpio,HWPin,
	idxofs_1Bit,
	idxofs_3Bit,nr	: longint;
	regget,
	regset,regclr,
	mask_pol,
	mask_3Bit,
	mask_1Bit		: longword;
	initok,ein		: boolean;
	ThreadCtrl		: Thread_Ctrl_t;
	FRQ_freq_Hz		: real;
	FRQ_CTLIdx,
	FRQ_DIVIdx		: longword;
	PWM				: PWM_struct_t;
	portflags		: s_port_flags;
  end;
      
  SERVO_struct_t = record
    HWAccess		: GPIO_struct_t;	// e.g. SG90 Micro Servo
	min_angle,							// -90 Degree	(max left turn)
	mid_angle,							//   0 Degree	(mid/neutral position)
	max_angle,							//  90 Degree	(max right turn)	
	speed60deg,							// Servo operating speed in msec for 60deg movement
	angle_current	: longint;
	period_us,							// Servo Period in us: 20000 (1000000 div 50Hz)
	min_dutycycle,						// 1  ms	@ 50Hz
	mid_dutycycle,						// 1.5ms
	max_dutycycle	: longword;			// 2  ms
  end;
  
  FREQ_Determine_t = record
    fdet_enab:boolean;
	fSyncTime:TDateTime;
	fTurnRate_Hz:real;
	fcnt,fcntold,fdet_ms:longint;
  end;  
  
  ENC_ptr = ^ENC_struct_t;
  ENC_CNT_ptr=^ENC_CNT_struct_t;
  ENC_CNT_struct_t = record	  
    Handle:integer;
    ENC_activity:boolean;
    switchcounter,switchcounterold,switchcountermax,switchlastpresstime,
    counter,counterold,countermax,cycles,cyclesold:longint;
    encsteps,enccycles,swsteps,Interval_ms:longint;
    enc,encold:real;
    fIntervalResetTime:TDateTime;
    activitymodedetect,
    steps_per_cycle:byte;
    kbdcode,kbdupcnt,kbddwncnt,kbdswitch:char;
    TurnRateStruct:FREQ_Determine_t;
  end; 
  ENC_struct_t = record					// Encoder data structure
    ENC_CS : TRTLCriticalSection;
	SyncTime: TDateTime;				// for syncing max. device queries
//  ENCptr:ENC_ptr; 
	ThreadCtrl:Thread_Ctrl_t;
	A_Sig,B_Sig,S_Sig:GPIO_struct_t;
	a,b,seq,seqold,deltaold,delta:longint;
	idxcounter,SwitchRepeatTime_ms,
	sleeptime_ms:longword;
	beepgpio:integer;
	ok,s2minmax:boolean;
	SwitchFiredSpecFunc:TProcedureNoArgCall;
	CNTInfo:ENC_CNT_struct_t;
	desc:string[RPI_hal_dscl];
  end;
  
  TRIG_ptr		= ^TRIG_struct_t;
  TRIG_struct_t = record
    TRIG_CS:	TRTLCriticalSection;
  	SyncTime:	TDateTime; 
	SyncTime_ms:longword;
	tim_ms:		longint;
	flg:		boolean;
    TGPIO:		GPIO_struct_t;
	ThreadCtrl:	Thread_Ctrl_t;
	desc:		string[RPI_hal_dscl];
  end;  
      
  SPI_databuf_t = record
    reg:	byte;
//  buf: 	array[0..(SPI_BUF_SIZE_c-1)] of byte;
	buf: 	string[SPI_BUF_SIZE_c];
	posidx,
	endidx:	longint;
  end;
  
  spi_ioc_transfer_t = record  	// sizeof(spi_ioc_transfer_t) = 32
    tx_buf_ptr		: qword;	// Ptr to tx buffer
    rx_buf_ptr		: qword;	// Ptr to rx buffer
    len				: longword;	// # of bytes
	speed_hz    	: longword;	// Clock rate in Hz
    delay_usecs		: word;		// in msec
    bits_per_word	: byte;	
    cs_change		: byte;		// apply chip select
    tx_nbits		: byte;
    rx_nbits		: byte;
    pad				: word;
  end;
  
  SPI_Bus_Info_t = record
    SPI_CS 			: TRTLCriticalSection;
    SPI_useCS		: boolean;
	spi_maxspeed	: longword;
  end;
 	
  SPI_Device_Info_t = record
	errhndl			: integer;
	spi_path 		: string;
	spi_fd   		: cint;
	spi_LSB_FIRST	: byte;     // Zero indicates MSB-first; other values indicate the less common LSB-first encoding.
	spi_bpw  		: byte; 	// bits per word 
	spi_delay 		: word; 	// delay usec 
	spi_speed 		: longword;	// spi speed in Hz 
	spi_cs_change  	: byte;     
	spi_mode  		: byte;     // 0..3 
	spi_IOC_mode	: longword; 
	dev_GPIO_ook,
	dev_GPIO_en 	: integer;
	isr_enable		: boolean;  // decides, establish and prepare INT-Environment. If false, then polling 
	isr				: isr_t;
  end;  
  
  tcflag_t = cuint;
  cc_t = cchar;
  speed_t = cuint;
  size_t = cuint;
  ssize_t = cint;
   
  Ptermios = ^termios;
  termios = record
     c_iflag : tcflag_t;
     c_oflag : tcflag_t;
     c_cflag : tcflag_t;
     c_lflag : tcflag_t;
     c_line : cc_t;
     c_cc : array[0..(NCCS)-1] of cc_t;
     c_ispeed : speed_t;
     c_ospeed : speed_t;
  end;
   
  Terminal_device_t = record
	fdmaster,fdslave,ridx,rlgt:longint; 
	masterpath,slavepath,linkpath:string;   
	si : array [1..Terminal_MaxBuf] of char; 
  end;
    
  PID_float_t=	real;
  PID_array_t=	array[0..2] of PID_float_t;
  
  PID_Method_t=	(	P_Default,PI_Default,PID_Default,
  					P_Oppelt,PI_Oppelt,PID_Oppelt,
  					P_ZiegNich,PI_ZiegNich,PID_ZiegNich,
  					P_SUM,PD_SUM,PI_SUM,PID_SUM,PI_SUM_Fast,PID_SUM_Fast,
					P_CHR_GSA,P_CHR_GFA,P_CHR_GS20,P_CHR_GF20,
					PI_CHR_GSA,PI_CHR_GFA,PI_CHR_GS20,PI_CHR_GF20,
					PID_CHR_GSA,PID_CHR_GFA,PID_CHR_GS20,PID_CHR_GF20,
					P_SAMAL_GSA,P_SAMAL_GFA,P_SAMAL_GS20,P_SAMAL_GF20,
					PI_SAMAL_GFA,PI_SAMAL_GF20,PI_SAMAL_GSA,PI_SAMAL_GS20,
					PID_SAMAL_GFA,PID_SAMAL_GF20,PID_SAMAL_GSA,PID_SAMAL_GS20);
					
PID_Twiddle_t = record
	twiddle_on,
	twiddle_saved:		boolean;
	twiddle_state,
	twiddle_idx,
	twiddle_intermax,
	twiddle_iterations:	longint;
	twiddle_sum_dp,
	twiddle_sum_dp_old,
	twiddle_best_error:	PID_float_t;
	twiddle_tol,
	err,p,dp,ps,dps:	PID_array_t;
	twiddle_INI_sect,
	twiddle_INI_key:	string;
  end;
  
  PID_Struct_t = record
	PID_nr:				longint;
	PID_cnt: 			longword;
	PID_dT,
	PID_LastdT:			int64;			// nano seconds
	PID_IntImprove,	
	PID_DifImprove,
	PID_LimImprove,
	PID_FirstTime,	
	PID_STimAdj,
	PID_UseSelfTuning:	boolean;
	PID_Time,
	PID_LastTime: 		timespec;
    PID_Ks,
    PID_Integrated, 	
    PID_PrevInput,
    PID_MinOutput,  	
    PID_MaxOutput,
    PID_Delta,
    PID_LastError,
    PID_LastSampleTime,
    PID_SampleTime,	
    PID_PrevAbsError:	PID_float_t;
	PID_K,PID_Ksav:		PID_array_t;
    PID_Twiddle:		PID_Twiddle_t;
  end;
  
  T_IniFileDesc = record
	inifilbuf:		TIniFile;
	ok:				boolean;	
	modifydate:		TDateTime;
	dfltflags:		s_BIOS_flags;
	dfltsection,
	inifilename:	string;	
  end;
  
  WAVE_RampShape_t = (LIN_Ramp,LIN_Triangle,LIN_SawTooth,LIN_Square,SINusoidal,S_Shape);
  WAVE_Array_t= array of real;
  WAVE_Signal_Struct_t = record
  	enable,
	up:		boolean;
	mode:	WAVE_RampShape_t; 
	idx,
	int_ms:	longint;
	timer:	TDateTime;
  end;
  
  cert_t = record
    ok:boolean;
    certtyp:Cert_Type_t;
	desc,filnam,id:string;
  end;
  cert_pack_t = record
	ok:		boolean;
	idx:	longint;
	packtyp:Cert_Type_t;
	desc,
	pwd:	string;
	cert:	array[CertPublic..CertCombined] of cert_t;	// 1:publicCert 2:privateKey 3:CaCert 4:CertCombined
  end;
   
  IP_Info_t = record
    stat,wireless:boolean;
	alias,iface,ip4addr,ip6addr,hwaddr,gwaddr,nsaddr,domain,
	link,ssid,signal,DNSname:string;
  end;
  
  IP_Infos_t = record
	idx:		longint;
    init,
    samesubnet:	boolean;
    devlst,ip4ext,
    hostname:	string;
    IP_Info: 	array[0..IP_infomax_c] of IP_Info_t;
  end;
  
  AlignmentSize_t = record
    c:char;
//    a:array[1..16] of byte;	// force data alignment to 32 byte
    b:array[1..15] of byte;
  end;
         
var
  dummy:AlignmentSize_t; // requires {$PACKRECORDS 32} 
msg:RPI_MBX_msg_t;	// 32 byte aligned
  mmap_arr:t_MemoryMapPtr;  
  CurlThreadCtrl:Thread_Ctrl_t;
  HighPrecisionMillisecondFactor:Int64=1000; 
  HighPrecisionMicrosecondFactor:Int64=1; 
  HighPrecisionTimerInit:boolean=false;
  terminateProg:boolean;
  RPI_MaintMinVersion,RPI_MaintMaxVersion:real;
  mem_fd:integer; 
  wdog:watchdog_struct_t;
  SDcard_root_hdl:byte;
  RPI_bType:byte;
  rtc_time:rtc_time_t; 
  LNX_UsrAuthModDateTime,RPI_ProgramStartTime:TDateTime;
  _TZLocal:longint; _TZOffsetString:string[10];
  IniFileDesc:T_IniFileDesc;
  RpiMaintCmd:TIniFile;
  PtrRPI_SignalRoutine:TcFunctionOneArgCall;
  MSG_HUB_ptr,CURL_ProgressUpdateHook_ptr:TFunctionThreeArgCall;

  USBDEVFS_RESET,
  SPI_IOC_RD_MODE,SPI_IOC_WR_MODE,SPI_IOC_RD_LSB_FIRST,SPI_IOC_WR_LSB_FIRST,
  SPI_IOC_RD_BITS_PER_WORD,SPI_IOC_WR_BITS_PER_WORD,SPI_IOC_RD_MAX_SPEED_HZ,
  SPI_IOC_WR_MAX_SPEED_HZ,IOCTL_TAG_PROPERTY,
  WDIOC_SETTIMEOUT,WDIOC_GETTIMEOUT,WDIOC_KEEPALIVE,WDIOC_GETBOOTSTATUS,
  WDIOC_GETSUPPORT,WDIOC_GETSTATUS:longword;
  
  RPI_ShutDown_RebootCall,RPI_ShutDown_Call:TProcedureNoArgCall;
  RPI_ShutDownMin_ms,RPI_ShutDownDebounce_ms:word; 
  RPI_ShutDown_struct:GPIO_struct_t;
  RPI_HW_initpart:s_initpart;
  
  HAT_Info:			HAT_Struct_t;
  IP_Infos:			IP_Infos_t;
  RPI_Temps:		RPI_Temps_t;
  CertPack:		array[CertPackRPIMaint..
  					 	CertPackLast]	of cert_pack_t;
    
  spi_bus: 		array[0..spi_max_bus]	of SPI_Bus_Info_t;
  spi_dev:		array[0..spi_max_bus,
					  0..spi_max_dev]	of SPI_Device_Info_t;
  spi_buf:		array[0..spi_max_bus,
					  0..spi_max_dev]	of SPI_databuf_t; 
  I2C_bus:		array[0..I2C_max_bus]	of I2C_Bus_Info_t; 
  I2C_buf:		array[0..I2C_max_bus]	of I2C_databuf_t; 
  
  ENC_struct: 	array					of ENC_struct_t;
  TRIG_struct: 	array					of TRIG_struct_t;
  SERVO_struct: array					of SERVO_struct_t;
  ERR_MGMT: 	array					of ERR_MGMT_t;
  
procedure AlignShow; 
function  RPI_HW_Start:boolean; // start all. GPIO,I2C and SPI
function  RPI_HW_Start(initpart:s_initpart):boolean; // start dedicated parts. e.g. RPI_HW_Start([InitGPIO,InitI2C,InitSPI]); 
function  RPI_HW_Start(initpart:s_initpart; p1,p2:string):boolean;
 
{$IFDEF UNIX} procedure GPIO_int_test; {$ENDIF}	// only for test   
procedure GPIO_PIN_TOGGLE_TEST; // just for demo reasons, call it from your own program. Be careful, it toggles GPIO pin 16 -> StatusLED }
procedure GPIO_Test(HWPinNr:longword; flags:s_port_flags);
procedure GPIO_TestAll;		// Test All GPIOs as OUTPUTs!!!
procedure GPIO_PWM_Test;	// Test with GPIO18 PWM0 on Connector Pin12
procedure GPIO_PWM_Test(gpio:longint; HWPWM:boolean; freq_Hz:real; dutyrange,startval:longword);
procedure FRQ_Test; 		// Test with GPIO4. 100kHz
procedure ENC_Test; 		// Encoder Test HWPins:15,16,18 
procedure SERVO_Test;		// Servo   Test HWPins:12,16,18 // GPIOs:18,23,24 
procedure SPI_Test; 
procedure SPI_Loop_Test;	
procedure I2C_test; 
procedure I2C_ZIP_Test;
procedure MEM_SpeedTest;
procedure CLK_Test;
procedure BIOS_Test;		// shows the usages of a config file
procedure CL_Test;			// CommandLineParser test
procedure GetDateTimefromXMLTimeStamp_Test;
procedure call_external_prog_Test;

function  _IOC (dir:byte; typ:char; nr,size:word):longword;
function  _IO  (typ:char; nr:word):longword; 
function  _IOR (typ:char; nr,size:word):longword;
function  _IOW (typ:char; nr,size:word):longword;
function  _IOWR(typ:char; nr,size:word):longword;

function  MSK_Get8		(bitnum:byte):byte; 
function  MSK_Get16_8	(bitnum:byte; var idxofs:byte):byte;
function  MSK_Get64_8	(bitnum:byte; var idxofs:byte):byte;
function  MSK_Get256_8	(bitnum:byte; var idxofs:byte):byte;

function  BCM_REGAdr(idx:longword):longword; 
function  BCM_GETREG(regidx:longword):longword;
procedure BCM_SETREG(regidx,newval:longword);  
procedure BCM_SETREG(regidx,newval:longword; and_mask,readmodifywrite:boolean);

function  RPI_Piggyback_board_available  : boolean;  
function  RPI_PiFace_board_available(devadr:byte) : boolean;  
function  RPI_run_on_known_hw:boolean;  
function  RPI_platform_ok:boolean;   			
function  RPI_mmap_run_on_unix:boolean;  
function  RPI_run_on_ARM:boolean; 
function  RPI_mmap_get_info (modus:longint)  : longword;
procedure RPI_HDR_SetDesc(HWPin:longint; desc:string);
procedure RPI_show_all_info;
procedure RPI_show_SBC_info;
function  RPI_WLANavailChan(cntry:string):string;

Function  RPI_FW_property(req,tag:longword; tag_data:pointer; buf_size:byte):longint;
procedure RPI_FW_test;

procedure RPI_MBX_test;

function  ERR_NEW_HNDL(adr:word; descr:string; maxerrs,AutoResetMsec:longword):integer; 
function  ERR_MGMT_STAT(errhdl:integer):boolean;
function  ERR_MGMT_GetErrCnt(errhdl:integer):longword;
procedure ERR_MGMT_UPD(errhdl:integer; cmdcode,datalgt:byte; modus:boolean);
procedure Toggle_STATUSLED_very_fast;
 
procedure LED_Status    (ein:boolean);		// Switch Status-LED on or off

procedure HDMI_Switch(ein:boolean);			// switch HDMI on/off 

function  CLK_GetFreq(clksource:longword):real; // Hz
function  CLK_GetMinFreq:real; 
function  CLK_GetMaxFreq:real; 

function  OSC_Setup(_gpio:longint; pwm_freq_Hz,pwm_dty:real):longint;
procedure OSC_Write(_gpio,pwm_dutyrange:longint; pwm_dty:real);

function  FRQ_Setup		(var GPIO_struct:GPIO_struct_t; freq_Hz:real):boolean;
procedure FRQ_Switch	(var GPIO_struct:GPIO_struct_t; ein:boolean);
function  TIM_Setup(timr_freq_Hz:real):real;
procedure TIM_Test; // 1MHz

procedure PWM_SetStruct (var GPIO_struct:GPIO_struct_t);  // set default values
procedure PWM_SetStruct (var GPIO_struct:GPIO_struct_t; mode:byte; freq_Hz:real; dutyrange,startval:longword);
function  PWM_Setup     (var GPIO_struct:GPIO_struct_t):boolean;
procedure PWM_Write     (var GPIO_struct:GPIO_struct_t; value:longword); // value: 0-1023
procedure PWM_SetClock  (var GPIO_struct:GPIO_struct_t); // same clock for PWM0 and PWM1. Needs only to be set once
procedure PWM_End		(var GPIO_struct:GPIO_struct_t);
function  PWM_GetDtyRangeVal(var GPIO_struct:GPIO_struct_t; DutyCycle:real):longword;
function  PWM_GetMinFreq(dutycycle:longword):longword;
function  PWM_GetMaxFreq(dutycycle:longword):longword;
function  PWM_GetMaxDtyC(freq:real):longword;
function  PWM_GetDRVal  (percent:real; dutyrange:longword):longword; 

procedure GPIO_ShowStruct(var GPIO_struct:GPIO_struct_t);
procedure GPIO_SetStruct(var GPIO_struct:GPIO_struct_t); // set default values
procedure GPIO_SetStruct(var GPIO_struct:GPIO_struct_t; num,gpionum:longint; desc:string; flags:s_port_flags);
procedure GPIO_Switch	(var GPIO_struct:GPIO_struct_t); // Read GPIOx Signal in Struct
procedure GPIO_Switch   (var GPIO_struct:GPIO_struct_t; switchon:boolean);
function  GPIO_Setup    (var GPIO_struct:GPIO_struct_t):boolean;

function  GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio:longint; mapidx:byte):longint; // Maps GPIO Number to the HDR_PIN 
function  GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio:longint):longint;
function  GPIO_MAP_HDR_PIN_2_GPIO_NUM(hdr_pin_number:longint; mapidx:byte):longint; // Maps HDR_PIN to the GPIO Number 
function  GPIO_MAP_HDR_PIN_2_GPIO_NUM(hdr_pin_number:longint):longint;

procedure GPIO_set_HDR_PIN(hw_pin_number:longword;highlevel:boolean); // Maps PIN to the GPIO Header 
function  GPIO_get_HDR_PIN(hw_pin_number:longword):boolean; // Maps PIN to the GPIO Header 

function  GPIO_FCTOK(gpio:longint; flags:s_port_flags):boolean;
procedure GPIO_set_pin     (gpio:longword;highlevel:boolean); // Set RPi GPIO pin to high or low level; Speed @ 700MHz ->  0.65MHz
function  GPIO_get_PIN     (gpio:longword):boolean; // Get RPi GPIO pin Level is true when Pin level is '1'; false when '0'; Speed @ 700MHz ->  1.17MHz 
procedure GPIO_Pulse	   (gpio,pulse_ms:longword);

procedure GPIO_set_input   (gpio:longword);         // Set RPi GPIO pin to input  direction 
procedure GPIO_set_output  (gpio:longword);         // Set RPi GPIO pin to output direction 
procedure GPIO_set_ALT     (gpio:longword; altfunc:t_port_flags); // Set RPi GPIO pin to ALT0..ALT5 
procedure GPIO_set_PINMODE (gpio:longword; portfkt:t_port_flags);
procedure GPIO_set_PAD	   (gpio:longword; noSLEW,noHYST:boolean; drivestrength:byte);
procedure GPIO_set_PULLUP  (gpio:longword; enable:boolean); // enable/disable PullUp
procedure GPIO_set_PULLDOWN(gpio:longword; enable:boolean); // enable/disable PullDown
procedure GPIO_set_edge_rising (gpio:longword; enable:boolean); // Pin RisingEdge  Detection Register (GPREN)
procedure GPIO_set_edge_falling(gpio:longword; enable:boolean); // Pin FallingEdge Detection Register (GPFEN)
procedure GPIO_get_mask_and_idx(regidx,gpio:longword; var idxabs,mask:longword);
{$IFDEF UNIX} 
function  GPIO_set_int    (var isr:isr_t; GPIO_num:longint; isr_proc:TFunctionOneArgCall; flags:s_port_flags):integer; // set up isr routine, GPIO_number, int_routine which have to be executed, rising or falling_edge
function  GPIO_int_release(var isr:isr_t) : integer;
procedure GPIO_int_enable (var isr:isr_t); 
procedure GPIO_int_disable(var isr:isr_t); 
function  GPIO_int_active (var isr:isr_t):boolean;
{$ENDIF}
procedure GPIO_show_regs;
procedure pwm_show_regs;
procedure q4_show_regs;
procedure Clock_show_regs;
function  GPIO_get_desc(regidx,regcontent:longword) : string;  
procedure GPIO_ShowConnector;
procedure GPIO_ConnectorStringList(tl:TStringList);

procedure FREQ_CounterReset	(var FREQ_Struct:FREQ_Determine_t);
procedure FREQ_InitStruct	(var FREQ_Struct:FREQ_Determine_t; detint_ms:longint);
procedure FREQ_DetTurnRate	(var FREQ_Struct:FREQ_Determine_t; steps:longint);

function  ENC_GetHdl		(descr:string):byte;
procedure ENC_InfoInit		(var CNTInfo:ENC_CNT_struct_t);
function  ENC_Setup(hdl:integer; stick2minmax:boolean; ctrpreset,ctrmax,stepspercycle:longword; beepergpio:integer):boolean;
procedure ENC_End			(hdl:integer);
function  ENC_GetVal		(hdl:byte; ctrsel:integer):real; 
function  ENC_GetVal		(hdl:byte):real; 
function  ENC_GetValPercent	(hdl:byte):real; 
function  ENC_GetSwitch		(hdl:byte):real;
function  ENC_GetCycles     (hdl:byte):real; 
function  ENC_GetCounter	(var ENCInfo:ENC_CNT_struct_t):boolean;
procedure ENC_IncEncCnt		(var ENCInfo:ENC_CNT_struct_t; cnt:integer);
procedure ENC_IncSwCnt		(var ENCInfo:ENC_CNT_struct_t; cnt:integer);
  
function  TRIG_Reg(gpio:longint; descr:string; flags:s_port_flags; synctim_ms:longword):integer;
procedure TRIG_End(hdl:integer); 
procedure TRIG_SetValue(hdl:integer; timesig_ms:longint);
function  TRIG_GetValue(hdl:integer; var timesig_ms:longint):integer;

procedure SERVO_Setup(var SERVO_struct:SERVO_struct_t; 
						HWPinNr,nr,maxval,
						dcmin,dcmid,dcmax:longword; 
						angmin,angmid,angmax,speed:longint;
						desc:string; freq:real; flags:s_port_flags);
procedure SERVO_SetStruct(var SERVO_struct:SERVO_struct_t; dty_min,dty_mid,dty_max:longword; ang_min,ang_mid,ang_max,speed:longint);
procedure SERVO_Write(var SERVO_struct:SERVO_struct_t; angle:longint; syncwait:boolean);
procedure SERVO_End(var SERVO_struct:SERVO_struct_t);

procedure BIOS_ReadIniFile(fname:string);
procedure BIOS_EndIniFile;
function  BIOS_CacheUpdate:boolean;
procedure BIOS_CacheUpdate(upd:boolean);

function  BIOS_GetIniNum(section,name:string; flgs:s_BIOS_Flags; default,minval,maxval:real):real;
function  BIOS_GetIniNum(section,name:string; default,minval,maxval:real):real;
function  BIOS_GetIniNum(name:string; default,minval,maxval:real):real;

function  BIOS_GetIniString(name,default:string):string;
function  BIOS_GetIniString(name,default:string; flgs:s_BIOS_Flags):string;
function  BIOS_GetIniString(section,name,default:string):string;
function  BIOS_GetIniString(section,name,default:string; flgs:s_BIOS_Flags):string;

function  BIOS_SetIniString(name,value:string):boolean;	
function  BIOS_SetIniString(section,name,value:string):boolean;	
function  BIOS_SetIniString(section,name,value:string; flgs:s_BIOS_Flags):boolean;

function  BIOS_DeleteKey(section,name:string):boolean;
procedure BIOS_EraseSection(section:string);
procedure BIOS_SetDfltSection(section:string);
procedure BIOS_SetDfltFlags(flags:s_BIOS_flags);
procedure USAGE_Init(nr:byte; var struct:HW_Usage_t; sect,key:string);

function  RPI_OSrev:string;// 9.1
function  RPI_snr :string; // 0000000012345678 
function  RPI_hw  :string; // BCM2708
function  RPI_fw  :string; // 2018-02-09T14:22:56
function  RPI_uname:string;// Linux pump 4.14.18-v7+ #1093 SMP Fri Feb 9 15:33:07 GMT 2018 armv7l GNU/Linux
function  RPI_machine:string;// armv7l
function  RPI_proc:string; // ARMv6-compatible processor rev 7 (v6l) 
function  RPI_mips:string; // 697.95 
function  RPI_feat:string; // swp half thumb fastmult vfp edsp java tls 
function  RPI_rev :string; // rev1;256MB;1000002 
function  RPI_freq:string; // 700000;700000;900000;Hz  	
function  RPI_Volt:string;	// core:1.2000V;sdram_c:1.2000V;sdram_i:1.2000V;sdram_p:1.2250V
function  RPI_FREQs:string;	// arm:600000000;core:250000000;h264:250000000;isp:250000000;...
function  RPI_Temp(logmsg:boolean):t_ERRORLevel;	//  TempInfo: CPU:41.8'C;GPU:50.464'C;WARN:65.0'C;ALARM:70.0'C;COOL:40.0'C	// temps in celsius
function  RPI_revnum:real; // 0:error
function  RPI_gpiomapidx:byte; // 1:rev1; 2:rev2; 3:B+; 0:error 
function  RPI_cores:longint;
function  RPI_BCM2835:boolean;
function  RPI_BCM2835_GetNodeValue(node:string; var nodereturn:string):longint;
function  RPI_status_led_GPIO:byte;	// give GPIO_NUM of Status LED
function  RPI_I2C_BRadj(i2c_speed_kHz:longint):longint;
function  RPI_I2C_busnum(func:byte):byte; // get the I2C busnumber, where e.g. the general purpose devices are connected. This depends on rev1 or rev2 board . e.g. RPI_I2C_busnum(RPI_I2C_general_purpose_bus_c) 
function  RPI_I2C_busgen:byte;  // general purpose bus
function  RPI_I2C_bus2nd:byte;  // 2.nd I2C bus
function  RPI_I2C_GetSpeed(bus:byte):longword;
function  RPI_I2C_GetFuncs(bus:byte):longword;
function  RPI_I2C_ChkFuncs(bus:byte; funcs:longword):boolean;
function  RPI_SPI_GetSpeed(bus:byte):longint;
function  RPI_hdrpincount:byte; // connector_pin_count on HW Header
function  RPI_GetBuildDateTimeString:string;
procedure RPI_show_cpu_info;
procedure RPI_MaintSetVersions(versmin,versmax:real); 
procedure RPI_MaintDelEnv;
procedure RPI_MaintSetEnvExec(EXECcmd:string);
procedure RPI_MaintSetEnvFTP(FTPServer,FTPUser,FTPPwd,FTPLogf,FTPDefaults:string);
procedure RPI_MaintSetEnvUPL(UplSrcPackageRemark,UplSrcFiles,UplDstDir,UplLogf:string);
procedure RPI_MaintSetEnvDWN(DwnSrcDir,DwnlSrcFiles,DwnDstDir,DwnLogf:string);
procedure RPI_MaintSetEnvUPD(UpdPkgSrcFile,UpdPkgDstDir,UpdPkgDstFile,UpdPkgMaintDir,UpdPkgLogf:string);
function  RPI_Maint(UpdFlags:s_rpimaintflags; var CurlThCtl:Thread_Ctrl_t):integer;
function  RPI_INFO_Split(info:string; var labl,valu:string):boolean;

procedure HAT_EEprom_Map(tl:TStringList; hwname,uuid,vendor,product:string; prodid,prodver,gpio_drive,gpio_slew,gpio_hysteresis,back_power:word; useDefault,EnabIO:boolean);
procedure HAT_EEprom_Map_Test; 
function  HAT_GetInfo:boolean;
function  HAT_GetInfo(ovrwrt:boolean; duuid,dvendor,dproduct,dsnr:string; dpid,dpver:longword):boolean;
procedure HAT_ShowStruct;
procedure HAT_GetStructInfo(HAT_INFO_tl:TStringList; lgt:byte);
function  HAT_vendor:string;	
function  HAT_product:string; 	
function  HAT_product_id:string; 
function  HAT_product_ver:string;
function  HAT_uuid:string; 
procedure HAT_Info_Test;

function  rtc_func(fkt:longint; fpath:string; var dattime:TDateTime) : longint;

function  USB_Reset(buspath:string):integer; // e.g. USB_Reset('/dev/bus/usb/002/004');
function  MapUSB(devpath:string):string;     // e.g. MapUSB('/dev/ttyUSB0') -> /dev/bus/usb/002/004

procedure I2C_show_struct (busnum:byte);
procedure I2C_Display_struct(busnum:byte; comment:string);
procedure HW_IniInfoStruct(var DeviceStruct:HW_DevicePresent_t);
procedure HW_SetInfoStruct(var DeviceStruct:HW_DevicePresent_t; DevTyp:t_IOBusType; BusNr,HWAdr:integer; dsc:string);
function  I2C_HWT(var DeviceStruct:HW_DevicePresent_t; bus,adr,lgt:word; cmds:string; Handle:integer; rv1,nv1,nv2,dsc:string):boolean;
function  I2C_HWSpeedT(var DeviceStruct:HW_DevicePresent_t; lgt:word; loops:longword; cmds,dsc:string):real;
function  I2C_HWSpeedT(BusNum,HWaddr,rdlgt:word; loops:longword; cmds,dsc:string):real;

procedure I2C_EnterCriticalSection(busnum:byte);
procedure I2C_LeaveCriticalSection(busnum:byte); 

//function  I2C_bus_SEGMENTS	(var zipdata:I2C_rdwr_zip_data_t):integer;
//procedure I2C_prep_iomsg	(var zipdata:I2C_rdwr_zip_data_t; baseadr,flag,lgt:word);
//procedure I2C_init_ZIPdata	(var zipdata:I2C_rdwr_zip_data_t; siz,busnum:word; errhdl:integer);

function  I2C_bus_WrRd		(busnum,baseadr:word; const WRbuf:string; WRflgs:word; var RDbuf:string; RDflgs:word; RDlen:byte; errhdl:integer):integer;
function  I2C_string_read	(busnum,baseadr:word; const WRbuf:string; RDlen:byte; errhdl:integer; var RDbuf:string):integer;
function  I2C_string_write	(busnum,baseadr:word; const WRbuf:string; errhdl:integer):integer; 
function  I2C_ChkBusAdr		(busnum,baseadr:word):boolean; 

//		** old I2C functions, pls. use above only. Just for compatibility reasons
function  I2C_byte_write	(busnum,baseadr,basereg:word; data:byte; errhdl:integer):integer; 
function  I2C_byte_read		(busnum,baseadr,basereg:word; errhdl:integer):byte; 
function  I2C_word_write	(busnum,baseadr,basereg:word; data:word; flip:boolean; errhdl:integer):integer; 
function  I2C_word_read		(busnum,baseadr,basereg:word; flip:boolean; errhdl:integer):word; 
function  I2C_string_read	(busnum,baseadr,basereg:word; RDlen:byte; errhdl:integer; var RDbuf:string):integer; 
function  I2C_string_write	(busnum,baseadr,basereg:word; WRbuf:string; errhdl:integer):integer;  
//function  I2C_bus_read    (busnum,baseadr,basereg:word; len:byte; errhdl:integer):integer;
//function  I2C_bus_write   (busnum,baseadr:word; errhdl:integer):integer;
function  oldI2C_string_read(busnum,baseadr,basereg:word; len:byte; errhdl:integer; var outs:string):integer;
function  oldI2C_string_read(busnum,baseadr:word; cmds:string; len:byte; errhdl:integer; var outs:string):integer; 
function oldI2C_string_write(busnum,baseadr:word; datas:string; errhdl:integer):integer; 
function oldI2C_string_write(busnum,baseadr,basereg:word; datas:string; errhdl:integer):integer;
// END	** old functions

function  SPI_HWT(var DeviceStruct:HW_DevicePresent_t; bus,adr,lgt:word; cmds:string; Handle:integer; rv1,nv1,nv2,dsc:string):boolean;
function  SPI_Dev_Init(busnum,devnum,bpw,cs_change:byte; mode,maxspeed_hz:longword; delay_usec:word):boolean;
function  SPI_Dev_Init(busnum,devnum:byte):boolean;
function  SPI_ClkWrite(spi_hz:real):longword;
procedure SPI_SetDevErrHndl(busnum,devnum:byte; errhdl:integer);
procedure SPI_EnterCriticalSection(busnum:byte);
procedure SPI_LeaveCriticalSection(busnum:byte);
function  SPI_Write(busnum,devnum:byte; basereg,data:word):integer;
function  SPI_Read (busnum,devnum:byte; basereg:word) : byte;
function  SPI_Transfer (busnum,devnum:byte; cmdseq:string):integer;
function  SPI_Mode(spifd:cint; mode:longword; pvalue:pointer):integer;
procedure SPI_StartBurst(busnum,devnum:byte; reg:word; writeing:byte; len:longint);
procedure SPI_EndBurst(busnum,devnum:byte);
function  SPI_BurstRead(busnum,devnum:byte):byte;
procedure SPI_BurstWriteBuffer(busnum,devnum,basereg:byte; len:longword);
procedure SPI_BurstRead2Buffer(busnum,devnum,basereg:byte; len:longword);
procedure SPI_show_buffer(busnum,devnum:byte);
procedure SPI_show_dev_info_struct(busnum,devnum:byte);
procedure SPI_show_bus_info_struct(busnum:byte);
procedure SPI_show_struct(var spi_strct:spi_ioc_transfer_t);

procedure eeprom_SetAddr(devaddr:word);
function  eeprom_write_page(startadr:word; datas:string):integer;
function  eeprom_read_page(startadr:word; len:byte; var outs:string):integer;

procedure BB_OOK_PIN(state:boolean);
procedure BB_SetPin(gpio:longint); 
function  BB_GetPin:longint; 
procedure BB_SendCode(switch_type:T_PowerSwitch; adr,id,desc:string; ein:boolean);
procedure BB_InitPin(id:string); // e.g. id:'TLP434A' or id:'13'  (direct RPI Pin on HW Header P1 )
procedure MORSE_speed(speed:integer); // 1..5, -1=default_speed
procedure MORSE_tx(s:string);
procedure MORSE_test;
procedure ELRO_TEST;

function  Thread_Start		(var ThreadCtrl:Thread_Ctrl_t; funcadr:TThreadFunc; paraadr:pointer; delaymsec:longword; prio:longint):boolean;
function  Thread_End  		(var ThreadCtrl:Thread_Ctrl_t; waitmsec:longword):boolean;
procedure Thread_InitStruct0(var ThreadCtrl:Thread_Ctrl_t);
procedure Thread_InitStruct	(var ThreadCtrl:Thread_Ctrl_t);
procedure Thread_InitStruct2(var ThreadCtrl:Thread_Ctrl_t; ThFunc:TThFunctionOneArgCall);
procedure Thread_SetName(name:string); 				
procedure Thread_ShowStruct(var ThreadCtrl:Thread_Ctrl_t);   
procedure SetTimeOut (var EndTime:TDateTime;TimeOut_ms:Int64);
function  TimeElapsed(var EndTime:TDateTime;Retrig_ms:Int64):boolean;
function  TimeElapsed(EndTime:TDateTime):boolean;
procedure SetTimeOut_us (ptspec_start,ptspec_end:Ptimespec; Retrig_us:int64);
procedure SetTimeOut_us (ptspec:Ptimespec; Retrig_us:int64);
function  TimeElapsed_us(ptspec:Ptimespec):boolean;
function  TimeElapsed_us(ptspec:Ptimespec; Retrig_us:int64):boolean;
//procedure Log_Write  (typ:T_ErrorLevel;msg:string);  // writes to STDERR
procedure Log_Writeln(typ:T_ErrorLevel;msg:string);  // writes to STDERR
procedure LOG_ShowStringList(typ:T_ErrorLevel; ts:TStringList); 
function  LOG_Level:t_ErrorLevel;    
procedure Log_Level(level:t_ErrorLevel);
procedure LOG_LevelSave; 
procedure LOG_LevelRestore; 
procedure LOG_LevelColor(enab:boolean);
function  LOG_GetEndMsg(comment:string):string;
function  LOG_GetVersion(version:real):string; 
function  LOG_Get_LevelStringShort(lvl:T_ErrorLevel):string;
		
procedure SAY   (typ:T_ErrorLevel; msg:string); // writes to STDOUT
procedure SAY   (typ:T_ErrorLevel; const msg:string; const params:array of const);overload;
procedure SAY_TL(typ:T_ErrorLevel; tl:TStringList); 
procedure SAY_Level(level:t_ErrorLevel); 

function  MSG_HUB(lvl:t_ErrorLevel; msgtype:MSG_Type_t; msg:string):longint;

function  GetHostName:string;
function  GetDomainName(iface:string):string;
function  GetDomainName:string;
function  GetMainDomainName:string;
function  GetWLANSignal(iface:string):longint; 	// -1,0-100
function  IP_iface(aliasname:string):string;
function  MAC_Addr(iface:string; fmt:byte):string;
function  IP4_Addr(iface:string):string;
function  IP6_Addr(iface:string):string;
function  IP4_AddrExt:string;
function  IP4_AddrValid(ipstr:string):boolean;
function  IP4AddrListValid(ipliststr:string):boolean;
function  IP6_AddrValid(ipstr:string):boolean;
function  IP6AddrListValid(ipliststr:string):boolean;
function  IPAddrListValid(ipliststr:string):boolean;
function  IP4AddrsInSameSubnet(ip4adr1,ip4adr2:string):boolean;

procedure LNX_sudo(sudouse:boolean);
function  LNX_sudo:boolean;
function  LNX_ParSET(filnam,parnam,parval:string):integer;
function  LNX_ParGET(filnam,parnam:string; var parval:string):integer;
function  LNX_ParLinEXIST(filnam,parstr:string):boolean;
function  LNX_GetProcessNumsByName(processname:string):string;
procedure LNX_KillProcesses(processlist:string; signal:word);
function  LNX_chmod(filename:string; mode:TMode):cint;
function  LNX_chowngrp(filename:string; owner,group:string):integer;
procedure LNX_GetUsrPwdString(StrList:TStringList; pwdfile,usrlst:string; carveflds:longint);
function  LNX_UpdPwdFile(pwdfile,usr,pwd:string):integer;
function  LNX_ChkUsrPwdValid(usr,pwd,pwddefault:string):integer;
function  LNX_ChgUsrPwd(usr,usrreq,pwd,pwd2,pwddflt,pwdold:string; PWD_OLDsameNEW:boolean; var msg:string):integer;
function  LNX_ChgUsrPwd(usr,pwd:string; var msg:string):integer;
function  LNX_GetRandomAccessToken(typ:longint):string;
function  LNX_GetTZList(ts:TStringList):integer;
function  LNX_GetNewestFile(filnampat:string):string;
function  LNX_LinkFile(filnam,linknam:string):integer;
function  LNX_tarSAV(target,fillst:string; flags:s_rpimaintflags):longint;
function  LNX_tarRST(target,fillst:string; flags:s_rpimaintflags):longint;
function  LNX_CertFormatTyp(certtyp:Cert_Type_t):string;
function  LNX_CertIDget(filnam:string; certtyp:Cert_Type_t; idouttyp:Cert_Type_t; var id:string):boolean;
procedure LNX_CertIDtest;
procedure LNX_CertInit(var certstruct:cert_t);
function  LNX_CertReg(var certstruct:cert_t; certfil:string; certtype:Cert_Type_t):boolean;
procedure LNX_CertPackShow(lvl:T_ErrorLevel; var certpack:cert_pack_t);
procedure LNX_CertInitPack(var certpack:cert_pack_t; num:longint); 
function  LNX_CertStartPack(var certpack:cert_pack_t; descr,pubcertfil,privkeyfil,cacertfil,combinedfil,passwd:string; certpacktyp:Cert_Type_t):boolean;
function  LNX_EncryptFile(filpubkey,filnam,ext:string; flags:s_rpimaintflags):integer;
function  LNX_DecryptFile(filprivkey,filnam,ext:string; flags:s_rpimaintflags):integer;
function  LNX_RemoveOldFiles(path2files:string; days:longint):integer;
function  LNX_ShellESC(s:string):string;
procedure LNX_ADD2Crontab(cmd:string);
function  LNX_ErrDesc(errno:longint):string;
function  LNX_SetDateTimeUTC(utc:TDateTime):boolean;
function  LNX_WDOG(wdog_action:t_rpimaintflags; p1:longint):longint;
function  LNX_WDOG(wdog_action:t_rpimaintflags):longint; 
function  LNX_SSHFSmount(site,pwd,mnt:string; var err:string):integer;
function  BTLE_StartBeaconURL(url1,url2:string):longint;
function  BTLE_StopBeacon:boolean;
procedure MinMaxAdj(var value:real; valmin,valmax:real);
function  Limits(var value:longint; minvalue,maxvalue:longint):longint;
function  Limits(var value:longword; minvalue,maxvalue:longword):longword;
function  Limits(var value:real; minvalue,maxvalue:real):real;
procedure MinMax(value:longint; var minvalue,maxvalue:longint);
procedure MinMax(value:longword; var minvalue,maxvalue:longword);
procedure MinMax(value:real; var minvalue,maxvalue:real);
procedure STAT_Init(var stats:STAT_struct_t; numoldval:word);
procedure STAT_Calc(var stats:STAT_struct_t; newval:real; tim_us:int64);

function  CL_Compose(cmdLine:string):string; 	
function  CL_Parse  (cmdLine:string):t_CLOptions; 
function  CL_OptGiven(var cl_opts:t_CLOptions; opt:string):integer;
 
function  FileAccessible(filnam:string):boolean;
procedure SetTextCol(typ:T_ErrorLevel);
procedure UnSetTextCol;
function  Upper(const s : string) : String; 
function  Lower(const s : string) : String;
function  Bool2Num(b:boolean) : byte;
function  Bool2Str(b:boolean) : string; 
function  Bool2LVL(b:boolean) : string; 	 
function  Bool2Dig(b:boolean) : string; 
function  Bool2Swc(b:boolean) : string;	 
function  Bool2OC (b:boolean) : string;
function  Bool2YN (b:boolean) : string;
function  Bool2YNS(b:boolean) : string;
function  Bool2EA (b:boolean) : string;
function  Bool2eas(b:boolean) : string;
function  Bool2UpDown(b:boolean):string;
function  TimeSpec2Str(pts:Ptimespec):string;
function  TimeSpec2Num(pts:Ptimespec):real;		
function  Str2Bool(s:string):boolean;
function  Str2Bool(s:string; var ein:boolean):boolean;
function  Num2Limit(var Value:real; MinOut,MaxOut:real):boolean;
function  Num2Str(num:int64):string; 
function  Num2Str(num:longint):string; 
function  Num2Str(num:longword):string;	
function  Num2Str(num:real;nk:byte):string;
function  Num2Str(num:int64;lgt:byte):string;
function  Num2Str(num:longint; lgt:byte):string;
function  Num2Str(num:longword;lgt:byte):string;
function  Num2Str(num:real;lgt,nk:byte):string;  
function  Str2Num(s:string; var num:byte):boolean;
function  Str2Num(s:string; var num:smallint):boolean;
function  Str2Num(s:string; var num:int64):boolean;
function  Str2Num(s:string; var num:qword):boolean;
function  Str2Num(s:string; var num:longint):boolean;
function  Str2Num(s:string; var num:longword):boolean;
function  Str2Num(s:string; var num:real):boolean; 
function  Str2Num(s:string; var num:extended):boolean;
function  Str2CP437(s:string):string;
function  Str2TimeSpec(s:string; var ts:timespec):boolean; 
function  Str2DateTime(tdstring,fmt:string; var dt:TDateTime):boolean;
function  Str2LogLvl(s:string):T_ErrorLevel;
function  LogLvl2Str(lvl:T_ErrorLevel):string;
function  GetLogLvls(tr:string):string;
function  LeadingZero(w : Word) : String; 
function  LeadingZeros(l:longint;digits:byte):string;  
function  Bin(q:longword;lgt:Byte) : string; 
function  Hex(nr:qword;lgt:byte) : string; 
function  Hex(ptr:pointer;lgt:byte): string;
function  HexStr(s:string):string;overload;
function  StrHex(Hex_strng:string):string;
function  AdjZahlDE(r:real;lgt,nk:byte):string;
function  AdjZahl(s:string):string;
function  FormatFileSize(const Size: Int64):string;
function  scale(valin,min1,max1,min2,max2:real):real;
function  Get_FixedStringLen(s:string;cnt:word;leading:boolean):string; 
function  ShortString(fmt,maxlgt,divdr:longint; str:string):string;
procedure AskCR;
procedure AskCR(msg:string);
procedure AskCR(lvl:T_ErrorLevel; msg:string);
function  AskYN(msg:string; dflt:string):boolean;
function  AskStr(msg:string; var outstr:string):boolean;
function  AskNum(von,bis:longint; msg:string; var outnum:longint):boolean;
function  SepRemove(s:string):string;
function  Trimme(s:string;modus:byte):string;//modus: 1:adjL 2:adjT 3:AdjLT 4:AdjLMT 5:AdjLMTandRemoveTABs
function  FilterChar(s,filter:string):string;
function  RemoveChar(s,filter:string):string;
function  GetNumChar(s:string):string;
function  GetAlphaNumChar(s:string):string;
function  GetParserTokenChar(s:string):string;
function  ContainDescenderLetter(s:string):boolean;
function  GetHexChar(s:string):string;
function  HashTag(var InString:string):string; 
function  HashTag(modus:byte; filname,comment1,comment2:string):string;
function  ReplaceChars(s,filterchars,replacechar:string):string;
function  RM_CRLF(s:string):string; 
function  SB_LF  (s:string):string; // \n -> #$0a
function  SB_CR  (s:string):string; // \r -> #$0d
function  SB_CRLF(s:string):string; 
function  SB_UnESC(s:string):string;
function  BS_LF  (s:string):string; // #$0a -> \n
function  BS_CR  (s:string):string; // #$0d -> \r
function  BS_CRLF(s:string):string; 
function  BS_DoESC(s:string):string;
function  BS_ALL (s:string):string;
function  IPInfo_GetIdx(intface:string):longint;
procedure IPInfo_GetOS(var IPInfos:IP_Infos_t);
procedure IPInfoShow(lvl:T_ErrorLevel; var IPInfo:IP_Info_t);
function  GetPrintableChars(s:string; c1,c2:char):string;
function  CamelCase(strng:string):string;
function  GetRndTmpFileName(filhdr,extname:string):string;
function  Get_FName(fullfilename:string):string; 
function  Get_FName(fullfilename:string; withext:boolean):string; 
function  Get_FNameExt(fullfilename:string):string; 
function  Get_ExtName(fullfilename:string; extwithdot:boolean):string; 
function  Get_Dir(fullfilename:string):string; 
function  Get_DirList(dirname:string; filelist:TStringList):integer;
function  GetTildePath(fullpath,homedir:string):string;
function  PrepFilePath(fpath:string):string;
function  IsDir(filname:string):boolean;
function  SetFileAge(filname:string; mode:integer; fdat:TDateTime):integer;
function  GetFileAge(filname:string):TDateTime;
function  GetFileSize(filname:string):int64;
function  GetFileAgeInSec(filname:string):int64;
function  FileIsRecent(filepath:string; seconds_old,varianz:longint):boolean;
function  FileIsRecent(filepath:string; seconds_old:longint):boolean;
function  MStream2String(MStreamIn:TMemoryStream):string;
procedure String2MStream(MStreamIn:TMemoryStream; var SourceString:string);
function  MStream2File(filname:string; StreamOut:TMemoryStream):boolean;
function  File2MStream(filname:string;StreamOut:TMemoryStream; var hash:string):boolean;
function  File2MString(filname:string; var OutString,hash:string):boolean;
function  TextFile2StringList(filname:string; StrListOut:TStringList; append:boolean; var hash:string):boolean;
function  StringListAdd2List(StrList1,StrList2:TStringList; append:boolean):longword; 
function  StringListAdd2List(StrList1,StrList2:TStringList):longword; //Adds StringList2 to Stringlist1. result is size of Stringlist in bytes
function  StringList2TextFile(filname:string; StrListOut:TStringList):boolean;
function  StringList2String(StrList:TStringList):string;
function  StringList2String(StrList:TStringList; tr:string):string;
procedure String2StringList(str:string; StrList:TStringList);
function  String2TextFile(filname:string; StrOut:string):boolean;
function  TailFile(filname:string; LinesCount:longint):RawByteString;
procedure TailFileFollow(filname:string; LinesCount:longint);
procedure TL_prot_Init(var tlp:TL_prot_t);
procedure TL_prot_Stop(var tlp:TL_prot_t);
function  Anz_Item(const strng,trenner,trenner2:string): longint;
function  Select_Item(const strng,trenner,trenner2,dflt:string;itemno:longint) : string; 
function  Select_Item(const strng,trenner,trenner2:string;itemno:longint) : string;
function  Select_RightItems(const strng,trenner,trenner2:string;startitemno:longint) : string; 
function  Select_LeftItems (const strng,trenner,trenner2:string;enditemno:longint) : string; 
function  Locate_Value(const strng,search,tr1,tr2,tr3,tr4:string; var valoutstrng:string):boolean;
function  CSV_RemLastSep(strng:string; sep:char):string;
function  CSV_RemFirstSep(strng:string; sep:char):string;
procedure CSV_MaintList(var csvlst:string; entry:string; addit:boolean);
function  CSV_MaintListToogleField(var csvlst:string; entry:string):boolean;
function  StringPrintable(s:string):string; 
procedure ShowStringList(StrList:TStringList); 
function  StringListMinMaxValue(StrList:TStringList; fieldnr:word; tr1,tr2:string; var min,max:extended; var nk:longint):boolean;
procedure StringListSnap(StrListIn,StrListOut:TStringList; srchstrng:string);
function  SearchStringInListIdx(StrList:TStringList; srchstrng:string; occurance,StartIdx:longint):longint;
function  SearchStringInList(StrList:TStringList; srchstrng:string):string;
function  GiveStringListIdx(StrList:TStringList; srchstrng:string; var idx:longint; occurance:longint):boolean;
function  GiveStringListIdx(StrList:TStringList; srchstrngSTART,srchstrngEND:string; var idx:longint):boolean;
function  GiveStringListIdx2(StrList:TStringList; srchstrng:string; var idxStart,idxEnd:longint):boolean;
procedure MemCopy(src,dst:pointer; size:longint); 
procedure MemCopy(src,dst:pointer; size,srcofs,dstofs:longint);
function  DeltaTime_in_ms(dt1,dt2:TDateTime):int64;
function  CRC8(s:string):byte;
function  MD5_HashGET(filnam:string; var MD5hash:string):boolean;
function  MD5_HashCreateFile(filnam,MD5filnam:string; var MD5hash:string):boolean;
function  MD5_HashGETFile(MD5filnam:string; var MD5hash:string):boolean;
function  MD5_Check(file1,file2:string):boolean;
function  MOD_Euclid(a,b:longint):longint;
function  MovAvg(interval:longword; var InpArr,OutArr:array of real):longint; // moving average
function  SearchValIdx(var InpArr:array of real; srchval,Epsilon:real):longint; 
function  TTY_sttySpeed(lvl:t_ErrorLevel; ttyandspeed:string):integer;  // e.g. '/dev/ttyAMA0@9600'
function  TTY_setterm(lvl:t_ErrorLevel; ttydev,ttyopts:string):integer; // e.g. '/dev/tty1' '--cursor off --clear all' 
function  TTY_console:string;
procedure SetUTCOffset; // time Offset in minutes form GMT to localTime
function  GetDateTimeLocal:TDateTime; 
function  GetDateTimeLocal(utc:TDateTime):TDateTime; 
function  CalcUTCOffsetString(offset_Minutes:longint; withcolon:boolean):string; // e.g. '+02:00'
function  GetUTCOffsetString:string; // e.g. '+02:00' 
function  GetUTCOffsetMinutes(offset_String:string):longint; // e.g. '-02:00' -> -120
function  GetDateTimeUTC:TDateTime;
function  GetDateTimeUTC(dt:TDateTime; tzofs:longint):TDateTime; 
function  GetXMLTimeStamp(dt:TDateTime):string; // YEAR-MM-DDThh:mm:ss.zzz+XX:XX
function  GetDateTimefromXMLTimeStamp(tstmp:string; var dt:TDateTime; var tzofs:longint):boolean;
function  GetDateTimefromUTC(tstmp:string; var dt:TDateTime):boolean;
function  call_external_prog(typ:t_ErrorLevel; cmdline:string):integer; 
function  call_external_prog(typ:t_ErrorLevel; cmdline:string; var receivestring:string):integer;
function  call_external_prog(typ:t_ErrorLevel; cmdline:string; receivelist:TStringList):integer; 
function  RunScript(filname,para:string):integer;
function  RunScript(ts:TStringList; para:string):integer;
function  RunScript(ts:TStringList; filname,para:string):integer;
function  RunProcess(filname,para:string; syncwait:boolean):integer;
function  RunProcess(cmds,filname,para:string; syncwait:boolean):integer;
function  RunProcess(ts:TStringList; filname,para:string; syncwait:boolean):integer;
function  PV_Progress(progressfile:string):integer;
function  CURLcmdCreate(usrpwd,proxy,ofil,uri:string; flags:s_rpimaintflags):string;
procedure CURL_RemoveProgressfile(progressfile:string);
function  CURL_DoProgressAction(var CurlThCtl:Thread_Ctrl_t; var terminate:boolean):boolean;
procedure CURL_SetPara(var CurlThCtl:Thread_Ctrl_t; info,curlcmd,logfile,filenamelist,dirname:string; updintervall_ms:integer; flgs:s_rpimaintflags);
function  CURL(var CurlThCtl:Thread_Ctrl_t):integer;
procedure CURL_Test;
procedure TimeElapsed_us_Test;
procedure delay_nanos(Nanoseconds:longword);
procedure delay_us   (Microseconds:longword);	
procedure delay_msec (Milliseconds:longword); 
function  GetHighPrecisionCounter: Int64; 

function clock_getres		(clock_id:clockid_t; res:Ptimespec):longint;cdecl;external clib name 'clock_getres';
function clock_gettime		(clock_id:clockid_t; tp: Ptimespec):longint;cdecl;external clib name 'clock_gettime';
function clock_settime		(clock_id:clockid_t; tp: Ptimespec):longint;cdecl;external clib name 'clock_settime';
function clock_nanosleep	(clock_id:clockid_t; flags:longint; req:Ptimespec; rem:Ptimespec):longint;cdecl;external clib name 'clock_nanosleep';
function clock_getcpuclockid(pid:pid_t; clock_id:Pclockid_t):longint;cdecl;external clib name 'clock_getcpuclockid';

{$IFDEF UNIX}
function  usleep(Microseconds:cuint64):longint;cdecl;external 'libc'; //name 'usleep';
function  getpt            :cint; cdecl;external 'c'; // name 'getpt';
function  grantpt (fd:cint):cint; cdecl;external 'c';
function  unlockpt(fd:cint):cint; cdecl;external 'c';
function  ptsname (fd:cint):pchar;cdecl;external 'c'; 
function  tcgetattr(fd:cint; termios_p:Ptermios):cint;cdecl;external 'c';
function  tcsetattr(fd:cint; optional_actions:cint; termios_p:Ptermios):cint;cdecl;external 'c';
procedure cfmakeraw(termios_p:Ptermios);cdecl;external 'c';
function  tcsendbreak(fd:cint; duration:cint):cint;cdecl;external 'c';
function  tcdrain(fd:cint):cint;cdecl;external 'c';
function  tcflush(fd:cint; queue_selector:cint):cint;cdecl;external 'c';

function  Term_ptmx(var termio:Terminal_device_t; link:string; menablemask,mdisablemask:longint):boolean;
function  TermIO_Read(var term:Terminal_device_t; rawmode:boolean):string;
procedure TermIO_Write(var term:Terminal_device_t; str:string);
procedure Test_BiDirectionDevice_in_UserSpace; // write and read from /dev/testbidir
function  FpPrCtl(options:cint; arg2,arg3,arg4,arg5:pointer):cint; cdecl; external clib name 'prctl';
function  MicroSecondsBetween(ts1,ts2:timespec):int64;
function  MicroSecondsBetween(ts:timespec):int64;
{$ELSE}
function  MicroSecondsBetween(ts1,ts2:int64):int64; 
{$ENDIF}
function  MilliSecsBetween(td:TDateTime):int64;

procedure PID_Test;

function  PID_DetPara(StrList:TStringList; idxStart,idxEnd,smoothdata,smoothtdr,loctim,locist,locSetPoint:longint; StoerSprung,timadjfct:real; var Ks,Te,Tb,Tsum,SampleTimeAvg:PID_float_t; tst:boolean):integer;
function  PID_GetPara(loglvl:t_ErrorLevel; Ks,Te,Tb,Tsum:PID_float_t; Method:PID_Method_t; var Ti,Td:PID_float_t; var K:PID_array_t):integer;

procedure PID_Init(var PID_Struct:PID_Struct_t; nr:longint; itermax:longword; enab_twiddle:boolean; Ks,MinOutput,MaxOutput,SampleTime_ms:PID_float_t; K,dK,tol:PID_array_t);
procedure PID_Reset(var PID_Struct:PID_Struct_t);
function  PID_Calc(var PID_Struct:PID_Struct_t; Setpoint,InputValue:PID_float_t; twiddle_postpone:boolean):PID_float_t;
function  PID_Calc(var PID_Struct:PID_Struct_t; Setpoint,InputValue:PID_float_t):PID_float_t;
procedure PID_SetIntImprove(var PID_Struct:PID_Struct_t; On_:boolean);
procedure PID_SetDifImprove(var PID_Struct:PID_Struct_t; On_:boolean);
procedure PID_SetMinMaxLimit(var PID_Struct:PID_Struct_t; MinOutput,MaxOutput:PID_float_t);
procedure PID_SetSampleTimeAdjust(var PID_Struct:PID_Struct_t; On_:boolean); 
procedure PID_SetSelfTuning(var PID_Struct:PID_Struct_t; On_:boolean); 
procedure PID_InitTwiddle(var PID_Struct:PID_Struct_t);
procedure PID_InitTwiddle(var PID_Struct:PID_Struct_t; enab:boolean; itermax:longword; ap,adp,tol:PID_array_t);

procedure PID_SetTwiddle_KeyName(var TWIDDLE_Struct:PID_Twiddle_t; sect,key:string);
function  PID_ReadTwiddle(sect,key:string; var K,dK,tol:PID_array_t):boolean;
function  PID_ReadTwiddle(var TWIDDLE_Struct:PID_Twiddle_t; var K,dK,tol:PID_array_t):boolean;
procedure PID_SaveTwiddle(var TWIDDLE_Struct:PID_Twiddle_t; K,dK:PID_array_t);

function  PID_VectorStr(var pidarr:PID_array_t; vk,nk:integer; sep:char):string;
function  PID_Vector(Kp,Ki,Kd:PID_float_t):PID_array_t;
function  PID_TDR(var TickArr,ValArr,OutTickDeltaArr,OutValArr:array of PID_float_t):longint;
function  PID_DetType(Te,Tb:PID_float_t):integer;
function  PID_TimAdj(timadjfct:real; var Te,Tb,TSum:PID_float_t):integer;
function  PID_DetAvgs(IdxStart,IdxEnd:longint; var avgnumIst,avgnumPInc:longint):boolean; 
function  PID_FileLoad(StrList:TStringList; filnam,SearchCrit:string; var IdxStart,IdxEnd:longint):boolean;
function  PID_sim(StrList:TStringList; simnr:integer):real;
procedure PID_SimCSV(tl:TStringList; var pid:PID_Struct_t);
procedure PID_Limit(var Value:PID_float_t; MinOut,MaxOut:PID_float_t);
procedure PID_TestSim;
function  PID_Info(var PID_Struct:PID_Struct_t; fmt:longint):string;

function  WAVE_InitArray(wavelist:TStringList; var wa:WAVE_Array_t; var valmin,valmax:real):longint;
function  WAVE_InitArray(var wa:WAVE_Array_t; wavemode:WAVE_RampShape_t; valstart,valend:real; valcnt:longint; dtycycle:real):longint;
procedure WAVE_InitStruct(var wstruct:WAVE_Signal_Struct_t; var wa:WAVE_Array_t; wavemode:WAVE_RampShape_t; intervall_ms:longint);
procedure WAVE_Enable(var wstruct:WAVE_Signal_Struct_t; enab:boolean);
function  WAVE_SetIdx(var wstruct:WAVE_Signal_Struct_t; var wa:WAVE_Array_t; startidx:longint):boolean;
function  WAVE_GetIdx(var wstruct:WAVE_Signal_Struct_t; var wa:WAVE_Array_t):boolean;
procedure WAVE_Show(var wstruct:WAVE_Signal_Struct_t; var wa:WAVE_Array_t);
procedure WAVE_Test;

implementation  

const int_filn_c='/tmp/GPIO_int_setup.sh';   
  	  prog_build_date = {$I %DATE%}; prog_build_time = {$I %TIME%}; 

var 
	_LOG_Level,_LOG_OLD_Level,_SAY_Level,_SAY_OLD_Level:T_ErrorLevel;
	rpi_fw_api:RPI_FW_API_t;
    rpi_timespecresolution:timespec;
    _LOG_LevelColor,restrict2gpio,_OnExitShowRuntime:boolean;
    GPIO_map_idx,I2C_busnum,connector_pin_count,status_led_GPIO:byte;
    cpu_snr,cpu_hw,cpu_proc,cpu_rev,cpu_mips,cpu_feat,cpu_fmin,cpu_fcur,
    cpu_machine,cpu_fmax,os_rev,cpu_fw,uname,sudo:string;
    cpu_rev_num,cpu_freq,pll_freq:real;
    BB_pin,RPI_ShutDownGPIO,cpu_cores: longint;
	MORSE_dit_lgt,eeprom_devadr:word; 
	GPU_MEM_BASE:longword;
	oa,na:PSigActionRec;
	RPIHDR_Desc:array[1..max_pins_c] of string[mdl];
	
//function  Aligned(p:pointer; alig:byte):boolean; begin Aligned:=((PtrUint(p) mod alig)=0); end; 
function  Aligned(p:pointer; alig:byte):boolean; begin Aligned:=(p=Align(p,alig)); end;
procedure AlignShow; 
begin 
  writeln('addr 0x'+Hex(@msg,8),' (',PtrUInt(@msg),') aligned ',Aligned(@msg,32),' (',(PtrUint(@msg) mod 32),')'); 
end;
	
function  MOD_Euclid(a,b:longint):longint;
var m:longint;
begin
  if (b<>0) then
  begin
	m:=a mod b;
  	if (m<0) then
      if (b<0) then m:=m-b else m:=m+b;
  end else m:=0;
  MOD_Euclid:=m;
end;

function  RoundUpPow2(nr:real):longword; begin RoundUpPow2:=round(intpower(2,round(log2(nr)))); end;
function  DivRoundUp(n,d:real):longword; begin DivRoundUp:=round((n+d-1)/d); end;	
procedure delay_msec (Milliseconds:longword);  begin if Milliseconds>0 then sysutils.sleep(Milliseconds); end;
function  CRC8(s:string):byte; var i,crc:byte; begin crc:=$00; for i := 1 to Length(s) do crc:=crc xor ord(s[i]); CRC8:=crc; end;
procedure SetTimeOut (var EndTime:TDateTime;TimeOut_ms:Int64); begin EndTime:=IncMilliSecond(now,TimeOut_ms); end;
function  TimeElapsed(EndTime:TDateTime):boolean;              begin TimeElapsed:=(EndTime<=now); end;

function  TimeElapsed(var EndTime:TDateTime; Retrig_ms:Int64):boolean;
var ok:boolean;
begin 
  ok:=(EndTime<=now); 
  if ok and (Retrig_ms>=0) then EndTime:=IncMilliSecond(now,Retrig_ms); 
  TimeElapsed:=ok; 
end;

(*
type timespec = record
  tv_sec: time_t;	//Seconds		cint64; INT64 (valid values are >= 0) 
  tv_nsec: clong;	//Nanoseconds	long; i32; nanoseconds(valid values are [0,999999999])
end;
*)

function  TimeSpec_Diff(ptspec_start,ptspec_end:Ptimespec):timespec;
// https://gist.github.com/diabloneo/9619917
const nano_c:longword=1000000000;
var ts:timespec;
begin
  if ((ptspec_end^.tv_nsec - ptspec_start^.tv_nsec) < 0) then
  begin
	ts.tv_sec:=	ptspec_end^.tv_sec 	- ptspec_start^.tv_sec  - 1;
	ts.tv_nsec:=ptspec_end^.tv_nsec - ptspec_start^.tv_nsec + nano_c;
  end
  else
  begin
	ts.tv_sec:=	ptspec_end^.tv_sec 	- ptspec_start^.tv_sec;
	ts.tv_nsec:=ptspec_end^.tv_nsec - ptspec_start^.tv_nsec;
  end;
  TimeSpec_Diff:=ts;
end; 

procedure SetTimeOut_ns (ptspec_start,ptspec_end:Ptimespec; Retrig_nsec:int64);
const nano_c:longword=1000000000;
begin
  clock_gettime(CLOCK_REALTIME,ptspec_start); 
  ptspec_end^.tv_sec:=ptspec_start^.tv_sec;
  if rpi_timespecresolution.tv_nsec=1 then
  begin 
	ptspec_end^.tv_nsec:=(ptspec_start^.tv_nsec + Retrig_nsec) mod nano_c;
  end
  else
  begin
    ptspec_end^.tv_nsec:=(ptspec_start^.tv_nsec + Retrig_nsec div rpi_timespecresolution.tv_nsec) mod nano_c;
  end;   
  if (ptspec_end^.tv_nsec < ptspec_start^.tv_nsec) 
	then begin if (Retrig_nsec>0) then inc(ptspec_end^.tv_sec); end
	else begin if (Retrig_nsec<0) then dec(ptspec_end^.tv_sec); end;
//say(Log_INFO,'SetTimeOut_ns: '+TimeSpec2Str(ptspec_start)+' '+TimeSpec2Str(ptspec_end)+' ('+Num2Str(rpi_timespecresolution.tv_nsec,0)+')');
end;
procedure SetTimeOut_us (ptspec_start,ptspec_end:Ptimespec; Retrig_us:int64);
begin 
 try
  SetTimeOut_ns(ptspec_start,ptspec_end,(Retrig_us*1000)); 
 except
  On E_rpi_hal_Exception :Exception do Writeln(LOG_ERROR,'SetTimeOut_us: ',Retrig_us,' ',E_rpi_hal_Exception.Message);
 end;
end;
procedure SetTimeOut_us (ptspec:Ptimespec; Retrig_us:int64);
var tv_start:timespec; begin SetTimeOut_us(@tv_start,ptspec,Retrig_us); end;

function  TimeElapsed_us(ptspec:Ptimespec; Retrig_us:int64):boolean;
var ok:boolean; tv_now:timespec;
begin 
  clock_gettime(CLOCK_REALTIME,@tv_now);
  ok:=(ptspec^.tv_nsec<=tv_now.tv_nsec);
  if ok and (Retrig_us>=0) then SetTimeOut_us(@tv_now,ptspec,Retrig_us);
  TimeElapsed_us:=ok;
end;

function  TimeElapsed_us(ptspec:Ptimespec):boolean;
begin TimeElapsed_us:=TimeElapsed_us(ptspec,-1) end;

{$IFDEF WINDOWS}
  function  CPUClockFrequency: Int64; var rslt:Int64; begin if not QueryPerformanceFrequency(rslt) then rslt:=-1; CPUClockFrequency:=rslt; end;
  procedure InitHighPrecisionTimer; var F : Int64; begin F := CPUClockFrequency; HighPrecisionMillisecondFactor := F div 1000; HighPrecisionMicrosecondFactor := F div 1000000; HighPrecisionTimerInit := True; end;
  function  GetHighPrecisionCounter: Int64; var rslt:Int64; begin if not HighPrecisionTimerInit then InitHighPrecisionTimer; QueryPerformanceCounter(rslt); GetHighPrecisionCounter:=rslt; end;
  procedure delay_nanos(Nanoseconds:longword); var i:longword; begin for i:=1 to 1000 do; end; // dummy
{$ELSE}
  function  GetHighPrecisionCounter: Int64; var rslt:Int64; TV : TTimeVal; TZ : PTimeZone; begin TZ := nil; fpGetTimeOfDay(@TV, TZ); rslt := Int64(TV.tv_sec) * 1000000 + Int64(TV.tv_usec); GetHighPrecisionCounter:=rslt; end;

  procedure delay_nanos(Nanoseconds:longword);
  var sleeper,dummy : timespec;
  begin
    sleeper.tv_sec  := 0;
    sleeper.tv_nsec := Nanoseconds;
    fpnanosleep(@sleeper,@dummy);
  end;
{$ENDIF}

{$IFDEF UNIX}
procedure delay_us(Microseconds:longword); begin usleep(Microseconds); end;

function  NanoSecondsBetween(ts1,ts2:timespec):int64;
const nano_c:longword=1000000000;
var i64:int64;
begin
  i64:=	(ts1.tv_sec * nano_c + ts1.tv_nsec) -
  		(ts2.tv_sec * nano_c + ts2.tv_nsec);
  if rpi_timespecresolution.tv_nsec<>1 then 
	i64:=  i64 div rpi_timespecresolution.tv_nsec;
  NanoSecondsBetween:=i64;
end;

function  MicroSecondsBetween(ts1,ts2:timespec):int64;
begin MicroSecondsBetween:=NanoSecondsBetween(ts1,ts2) div 1000; end;

function  MicroSecondsBetween(ts:timespec):int64;
var tsnow:timespec;
begin 
  clock_gettime(CLOCK_REALTIME,@tsnow);
  MicroSecondsBetween:=MicroSecondsBetween(tsnow,ts); 
end;

function  MilliSecsBetween(td:TDateTime):int64;
begin MilliSecsBetween:=MilliSecondsBetween(now,td); end;

procedure TimeElapsed_us_Test;
(* 	TimeElapsed_us_Test: 720688613 720863195
	TimeDelta in Microseconds: 174us
	SetTimeOut_us: 720972204 1 721072204 *)
var tv_start,tv_end,tvh:timespec;
begin
  writeln('rpi_timespecresolution:   ',rpi_timespecresolution.tv_nsec,'ns');

  clock_gettime(CLOCK_REALTIME,@tv_start); 
  //delay_us(100); 
  usleep(100); 
  clock_gettime(CLOCK_REALTIME,@tv_end);
  writeln('TimeElapsed_us_Test:      ',tv_end.tv_nsec,'-',tv_start.tv_nsec,'=',NanoSecondsBetween(tv_end,tv_start),'ns / ',MicroSecondsBetween(tv_end,tv_start),'us');
  writeln('TimeDelta in NanoSeconds: ',tv_end.tv_nsec,'-',tv_start.tv_nsec,'=',(tv_end.tv_nsec-tv_start.tv_nsec),'ns');
  
  tv_end.tv_nsec:=tv_start.tv_nsec+100000;
  writeln('TimeElapsed_us_Test:      ',tv_end.tv_nsec,'-',tv_start.tv_nsec,'=',NanoSecondsBetween(tv_end,tv_start),'ns / ',MicroSecondsBetween(tv_end,tv_start),'us');
  writeln('TimeDelta in NanoSeconds: ',tv_end.tv_nsec,'-',tv_start.tv_nsec,'=',(tv_end.tv_nsec-tv_start.tv_nsec),'ns');
  
  writeln;
  SetTimeOut_us(@tv_start, @tv_end,10000);		// requested 10000ns
  while not TimeElapsed_us(@tv_end) do ;
  clock_gettime(CLOCK_REALTIME,@tvh); 			// real time
  writeln('Test TimeElapsed:         ',NanoSecondsBetween(tv_end,tv_start),'ns');
  writeln(' precision error:         ',NanoSecondsBetween(tvh,tv_start)-NanoSecondsBetween(tv_end,tv_start),'ns');
//TimeElapsed_us_Test:      327148143-317147476=10000667ns / 10000us  
end;
{$ELSE}
procedure delay_us(Microseconds:int64);
// https://github.com/fundamentalslib/fundamentals5/blob/master/Source/Utils/flcTimers.pas
var i,j,f:int64; n:longint;
begin
  if Microseconds>0 then
  begin
    i:=GetHighPrecisionCounter;
	if Microseconds>900 then
	begin
	  n:= longint((Microseconds-900) div 1000); // number of ms with at least 900us in tight loop
      if n>0 then begin sysutils.sleep(n); end;	
	end;
    f:=int64(Microseconds*HighPrecisionMicrosecondFactor);
    repeat j:=GetHighPrecisionCounter; until (int64(j-i)>=f);
  end;
end;

function  MicroSecondsBetween(us1,us2:int64):int64;
begin MicroSecondsBetween:=int64((us1-us2)*HighPrecisionMicrosecondFactor); end;

procedure TimeElapsed_us_Test;
const retrig_us=1000;
var i,j,n:int64; td:TDateTime;
begin
  writeln('TimeElapsed_us_Test: Start');
  n:=1; td:=now; i:=GetHighPrecisionCounter; j:=i;
  repeat
    if TimeElapsed_us(i,retrig_us) then inc(n);
  until (n>=10000);
  writeln('TimeElapsed_us_Test: ',MilliSecondsBetween(now,td),'ms ',MicroSecondsBetween(i,j),'us');
end;
{$ENDIF}

procedure USAGE_Init(nr:byte; var struct:HW_Usage_t; sect,key:string);
var sh:string;
begin
  with struct do
  begin
    sh:=Select_Item(BIOS_GetIniString(sect,key,''),';','',nr);
    if not Str2Num(Select_Item(sh,',','',1),usecnt) 		then usecnt:=0;
    if not Str2Num(Select_Item(sh,',','',2),usetimesec)	then usetimesec:=0;
    dat:=now;
  end;
end;

function  CalcUTCOffsetString(offset_Minutes:longint; withcolon:boolean):string; // e.g. '+02:00'
var sh,sh1:string; mins,hours:longint;
begin
  if offset_Minutes<0 then sh:='-' else sh:='+'; 
  mins:=abs(offset_Minutes) mod 60; hours:=abs(offset_Minutes) div 60;
  sh1:='00'+Num2Str(hours,0); 
  sh:=sh+copy(sh1,Length(sh1)-1,2); 
  if withcolon then sh:=sh+':';
  sh1:='00'+Num2Str(mins,0); sh:=sh+copy(sh1,Length(sh1)-1,2);
//if sh='+00:00' then sh:='Z';
  CalcUTCOffsetString:=sh;
end;

procedure SetUTCOffset; // time Offset in minutes form GMT to localTime 
{$IFDEF MSWINDOWS} var BiasType: Byte; TZInfo: TTimeZoneInformation; {$ENDIF}
begin
  _TZLocal:=0;
  {$IFDEF WINDOWS}
    BiasType := GetTimeZoneInformation(TZInfo);
	case BiasType of // Determine offset 
	   0 : _TZLocal := 0;
       2 : _TZLocal := -(TZInfo.Bias + TZInfo.DaylightBias);	   
	  else _TZLocal := -(TZInfo.Bias + TZInfo.StandardBias);
	end;
    //writeln('Bias ',BiasType,' ',TZInfo.Bias,' ',TZInfo.DaylightBias,' ',TZInfo.StandardBias);
  {$ENDIF}
  {$IFDEF UNIX} 
    _TZLocal := Tzseconds div 60; 
  {$ENDIF}
  _TZOffsetString:=CalcUTCOffsetString(_TZLocal,true);
end;

function  GetUTCOffsetString:string; // e.g. '+02:00'
begin GetUTCOffsetString:=_TZOffsetString; end;

function  GetUTCOffsetMinutes(offset_String:string):longint; // e.g. -02:00 -> -120
var mins,hours:longint; 
begin
  mins:=0; hours:=0;
  if (Upper(offset_String)<>'Z') and (offset_String<>'') then
  begin
    if not Str2Num(Select_Item(offset_String,':','',2),mins)  then mins:= 0;
	if not Str2Num(Select_Item(offset_String,':','',1),hours) then hours:=0;
  end;
  GetUTCOffsetMinutes:=hours*60+mins;
end;

function  GetDateTimeUTC(dt:TDateTime; tzofs:longint):TDateTime; begin GetDateTimeUTC:=IncMinute(dt,-tzofs); end;
function  GetDateTimeUTC:   TDateTime; begin GetDateTimeUTC:=GetDateTimeUTC(now,_TZLocal); end;
function  GetDateTimeLocal: TDateTime; begin GetDateTimeLocal:=now; end;
function  GetDateTimeLocal(utc:TDateTime):TDateTime; begin GetDateTimeLocal:=IncMinute(utc,_TZLocal); end;

function  GetDateTimefromUTC(tstmp:string; var dt:TDateTime):boolean;
// IN: 'Fri, 22 Jun 2018 15:05:27 GMT'
var _ok:boolean;
begin
  try
	dt:=ScanDateTime('ddd, dd mmm yyyy hh:nn:ss',tstmp);
	_ok:=true;
  except
    _ok:=false;
  end;
  GetDateTimefromUTC:=_ok;
end;

function  GetXMLTimeStamp(dt:TDateTime):string; // YEAR-MM-DDThh:mm:ss.zzz+XX:XX
begin GetXMLTimeStamp:=FormatDateTime('YYYY-MM-DD"T"hh:mm:ss.zzz',dt)+_TZOffsetString; end; 

function  GetDateTimefromXMLTimeStamp(tstmp:string; var dt:TDateTime; var tzofs:longint):boolean;
// IN: 2018-06-26T16:01:12.070+02:00
var _ok:boolean; p:longint; dats,tims:string; 
begin    
  p:=Pos('T',tstmp);
  if (p>0)
	then begin tims:=copy(tstmp,p+1,Length(tstmp)); dats:=copy(tstmp,1,p-1); end 
	else begin tims:=tstmp; dats:=FormatDateTime('YYYY-MM-DD',now); end;
  
  				p:=Pos('Z',tims);	// 16:01:12.070Z
  if (p=0) then p:=Pos('+',tims);	// 16:01:12.070+02:00
  if (p=0) then p:=Pos('-',tims);	// 16:01:12.070-02:00
  if (p>0) then
  begin
    tzofs:= GetUTCOffsetMinutes(copy(tims,p,Length(tims)));
    tims:=	copy(tims,1,p-1);
  end else tzofs:=0;
//writeln(dats,'|',tims,'|',tzofs,'|');
  try
	_ok:=	Str2DateTime(dats+' '+tims,'YYYY-MM-DD hh:mm:ss.zzz',dt);
	if not _ok then 
	  _ok:=	Str2DateTime(dats+' '+tims,'YYYY-MM-DD hh:mm:ss',dt);
  except
    _ok:=false;
  end;
  GetDateTimefromXMLTimeStamp:=_ok
end;

function  xGetDateTimefromXMLTimeStamp(tstmp:string; var dt:TDateTime; var tzofs:longint):longint;
// if res bit set (part included): Bit2=1:TZofs Bit1=1:DatePart Bit0=1:msecPart Bit3-6:reserved
// res:  <0	-> invalid XMLDateTimeString (and Bit13 set)
// res:   0	-> contains TimePart only
// res: 1-7 -> contains TimePart and further parts according to bit set
var res,p:longint; dats,tims,msecs,tzofss:string; 
begin  
  res:=0; dt:=now; dats:=FormatDateTime('YYYY-MM-DD',now); 
  tims:=tstmp; msecs:='000'; tzofss:='+00:00';
  
  if Pos('T',tstmp)>0 then
  begin 
	dats:=Select_Item(tstmp,'T','',1); tims:=Select_Item(tstmp,'T','',2); 
	res:=(res or $02);	// contains Date part
  end;
  				p:=Pos('Z',tims);	// 16:01:12.070Z
  if (p=0) then p:=Pos('+',tims);	// 16:01:12.070+02:00
  if (p=0) then p:=Pos('-',tims);	// 16:01:12.070-02:00
  if (p>0) then
  begin
	tzofss:=copy(tims,p,Length(tims));
    tims:=	copy(tims,1,p-1);
    res:=	(res or $04);	// contains TZofs part
    tzofs:= GetUTCOffsetMinutes(tzofss);
  end else tzofs:=0;
  
  if Pos('.',tims)>0 then
  begin
    msecs:=Select_Item(tims,'.','',2); tims:=Select_Item(tims,'.','',1);
    res:=(res or $01);	// contains msec part
  end;
  
//det field contains '*'
  if 					  msecs='*'	then res:=(res or $0010);	// msec  contains * 
  if Select_Item(tims,':','',3)='*' then res:=(res or $0020);	// sec   contains * 
  if Select_Item(tims,':','',2)='*' then res:=(res or $0040);	// min   contains * 
  if Select_Item(tims,':','',1)='*' then res:=(res or $0080);	// hour  contains * 
  if Select_Item(dats,'-','',3)='*' then res:=(res or $0100);	// day   contains *
  if Select_Item(dats,'-','',2)='*' then res:=(res or $0200);	// month contains * 
  if Select_Item(dats,'-','',1)='*' then res:=(res or $0400);	// year  contains * 
  
  if ((res and $0010)>0) then msecs:='000';	// msec
  if ((res and $00e0)>0) then tims:= StringReplace(tims, '*','00', [rfReplaceAll,rfIgnoreCase]); 	// hh:mm:ss 
  if ((res and $0700)>0) then dats:= StringReplace(dats, '*','01', [rfReplaceAll,rfIgnoreCase]);	// YYYY-MM-DD
  
//writeln(dats,'|',tims,'|',msecs,'|',tzofss,'|');
  if not Str2DateTime(dats+'T'+tims+'.'+msecs,'YYYY-MM-DD"T"hh:mm:ss.zzz',dt)
	then res:=-(res or $2000);	// dt is not valid, but Bit0-2 show Parts
  
  xGetDateTimefromXMLTimeStamp:=res;
end;

procedure TST_GetDateTimefromXMLTimeStamp(tstmp:string);
var ok:boolean; dt:TDateTime; tzofs:longint;
begin
  dt:=0;
  writeln(tstmp); 
  ok:=GetDateTimefromXMLTimeStamp(tstmp,dt,tzofs);
  writeln(FormatDateTime('YYYY-MM-DD" "hh:mm:ss.zzz',dt),' ',tzofs:0,' ',ok);
  if ok then
    writeln(FormatDateTime('YYYY-MM-DD" "hh:mm:ss.zzz',GetDateTimeUTC(dt,tzofs)),' (UTC)');
  writeln;
end;

procedure GetDateTimefromXMLTimeStamp_Test;
begin
  TST_GetDateTimefromXMLTimeStamp('2017-07-06T16:01:12.070-02:00');
  TST_GetDateTimefromXMLTimeStamp('16:01:12.070+02:00');
  TST_GetDateTimefromXMLTimeStamp('16:01:12+02:00');
  TST_GetDateTimefromXMLTimeStamp('16:01:12.123456');
  TST_GetDateTimefromXMLTimeStamp('16:01:12.070Z');
  TST_GetDateTimefromXMLTimeStamp('2017-07-06 16:01:12.070-02:00');
end;

function  LogLvl2Str(lvl:T_ErrorLevel):string;
begin 
  LogLvl2Str:=StringReplace(
  	GetEnumName(TypeInfo(T_ErrorLevel),ord(lvl)),'LOG_','',[rfReplaceAll,rfIgnoreCase]);
end;

function  Str2LogLvl(s:string):T_ErrorLevel;
var lvl:T_ErrorLevel; slvl:string;
begin
  lvl:=LOG_WARNING; slvl:=Upper(s);
  if Pos('ERROR',	slvl)>0 then lvl:=LOG_ERROR; 
  if Pos('WARNING', slvl)>0 then lvl:=LOG_WARNING; 
  if Pos('NOTICE',	slvl)>0 then lvl:=LOG_NOTICE; 
  if Pos('INFO',	slvl)>0 then lvl:=LOG_INFO; 
  if Pos('DEBUG',	slvl)>0 then lvl:=LOG_DEBUG;
  if Pos('URGENT',	slvl)>0 then lvl:=LOG_URGENT;   
  if Pos('NONE',	slvl)>0 then lvl:=LOG_NONE;   
  if Pos('ALL',		slvl)>0 then lvl:=LOG_ALL;   
  Str2LogLvl:=lvl;
end;

function  GetLogLvls(tr:string):string;
var sh:string;
begin
  sh:='ERROR'+tr+'WARNING'+tr+'INFO';
  GetLogLvls:=sh;
end;

function  LOG_Get_LevelStringShort(lvl:T_ErrorLevel):string;
var  s:string;
begin
  s:=''; 
  case lvl of
    LOG_WHITE,LOG_BLACK,LOG_BLUE,LOG_LHTGRN,
  	LOG_GREEN,LOG_YELLOW,LOG_ORANGE,
  	LOG_RED:	begin s:='COL'; end; 
(*  LOG_RED:	begin s:='RED'; end;
  	LOG_ORANGE:	begin s:='ORA'; end;
  	LOG_YELLOW:	begin s:='YLW'; end;
  	LOG_GREEN:	begin s:='GRN'; end;
  	LOG_BLUE:	begin s:='BLU'; end;
  	LOG_BLACK:	begin s:='BLK'; end;
  	LOG_WHITE:	begin s:='WHT'; end; *)
  	
    LOG_ERROR:	begin s:='ERR'; end;
    LOG_WARNING:begin s:='WRN'; end;
    LOG_NOTICE:	begin s:='SUC'; end;
    LOG_INFO:	begin s:='INF'; end;
    LOG_DEBUG:	begin s:='DBG'; end;
	LOG_URGENT:	begin s:='URG'; end;
	LOG_ALL: 	begin s:='ALL'; end;
	LOG_NONE2,
	LOG_NONE: 	begin s:='NON'; end;
  end;
  LOG_Get_LevelStringShort:=s;
end;

function Get_LogString(host,processname,processnr:string;typ:T_ErrorLevel):string;
{.c delivers LogString Header with format: YEAR-MM-DD hh:mm:ss host processname[processnr] }
var  s:string;
begin
  s:=FormatDateTime('YYYY-MM-DD hh:mm:ss',now);
  if host        <>'' then s:=s+' '+host;
  if processname <>'' then s:=s+' '+processname;
  if processnr   <>'' then s:=s+' ['+processnr+']';
  s:=s+' '; 
 (* s:=s+' NC'+' ['+host+'] '; *)
 (*	s:=s+' '+host+' ['+processnr+'] '; *)
  s:=s+LOG_Get_LevelStringShort(typ)+' ';
  Get_LogString:=s;
end;

function  FileAccessible(filnam:string):boolean;
var res:longint; {$IFDEF UNIX}info:stat;{$ENDIF}
begin
  res:=-1; filnam:=PrepFilePath(Trimme(filnam,3));
  if (filnam<>'') then
  begin
{$IFDEF UNIX}
	if (fpstat(filnam,info)<>0) then 
	begin
	  res:=fpGetErrNo;
	  LOG_Writeln(LOG_ERROR,'FileAccessible['+Num2Str(res,0)+'] '+SysErrorMessage(res)+': '+filnam);
	end else res:=0;
{$ELSE}
	if FileExists(filnam) then res:=0;
	if (res<>0) then LOG_Writeln(LOG_ERROR,'FileAccessible: file not exist '+filnam);
{$ENDIF}
  end; 
  FileAccessible:=(res=0);
end;

procedure ColTest;
var b:byte;
begin
  for b:=0 to 255 do
  begin
    if (b<>blink) then
    begin // no blink
	  TextColor(b);
	  SAY(LOG_INFO,Num2Str(b,3)+' TextTextTextTextTextTextTextTextTextTextText');
	end else SAY(LOG_INFO,Num2Str(b,3)+' Blink');
	NormVideo;
  end;
end;

procedure SetTextCol(typ:T_ErrorLevel);
begin
  if _LOG_LevelColor then 
  begin
	case typ of
        LOG_ERROR:	TextColor(red);
      	LOG_WARNING:TextColor(yellow);
      	LOG_NOTICE:	TextColor(green);
    end; // case
  end;
end;
procedure UnSetTextCol; begin if _LOG_LevelColor then NormVideo; end;

function  MSG_HUB(lvl:t_ErrorLevel; msgtype:MSG_Type_t; msg:string):longint;
// Hook to pass messages to upper level units. OLED displays...
// install: MSG_HUB_ptr:=@YourOwnFunction;
var res:longint;
begin
  if (MSG_HUB_ptr<>nil) then res:=MSG_HUB_ptr(lvl,msgtype,msg) else res:=-1;
  MSG_HUB:=res;
end;
// writes to STDOUT
function  SAY_Level:t_ErrorLevel; 		 begin SAY_Level:=_SAY_Level; end;
procedure SAY_LevelSave;    	 		 begin _SAY_OLD_Level:=_SAY_Level; end;
procedure SAY_Level(level:t_ErrorLevel); begin SAY_LevelSave; if level<LOG_NONE then _SAY_Level:=level else _SAY_Level:=LOG_NONE2; end;
procedure SAY_LevelRestore; 			 begin SAY_Level(_SAY_OLD_Level); end;
procedure SAY   (typ:T_ErrorLevel; msg:string); 
begin if typ>=_SAY_Level then begin SetTextCol(typ); writeln(Get_LogString('','','',typ)+msg+#$0d); UnSetTextCol; end; end;
procedure SAY   (typ:T_ErrorLevel; const msg:string; const params:array of const);overload; begin SAY(typ,Format(msg,params)); end;
procedure SAY_TL(typ:T_ErrorLevel; tl:TStringList); var i:longint; begin for i:=1 to tl.count do SAY(typ,tl[i-1]); end;

procedure Log_Writeln(typ:T_ErrorLevel;msg:string); 
begin
  if typ>=_LOG_Level then 
  begin 
	SetTextCol(typ); 
	write(StdErr,#$0d+Get_LogString('','','',typ)+msg+#$0d+#$0a); 
	UnSetTextCol; 
  end else write(StdErr,#$0d);
end;

function  Log_Shorting:boolean; begin Log_Shorting:=false; end; 

procedure LOG_ShowStringList(typ:T_ErrorLevel; ts:TStringList); 
var i:longint; 
begin 
  if (typ>=_LOG_Level) then 
  begin 
    if LOG_Shorting then 
	begin
	  if ts.Count>=35 then
	  begin
	    for i := 1          to 13       do Log_Writeln(typ,ts[i-1]);
		                                   Log_Writeln(typ,'<! Output shortend, total lines: '+Num2Str(ts.count,0)+'>');
		for i := ts.Count-6 to ts.Count do Log_Writeln(typ,ts[i-1]);
	  end
	  else for i := 1 to ts.Count do Log_Writeln(typ,ts[i-1]);
	end
	else
    begin
	  for i := 1 to ts.Count do Log_Writeln(typ,ts[i-1]);
    end;	
    Flush(ErrOutput);	
  end; 
end;

function  LOG_Level:t_ErrorLevel; 		 begin LOG_Level:=_LOG_Level; end;
procedure LOG_LevelSave;    			 begin _LOG_OLD_Level:=_LOG_Level; end;
procedure LOG_Level(level:T_ErrorLevel); begin LOG_LevelSave; if level<LOG_NONE then _LOG_Level:=level else _LOG_Level:=LOG_NONE2; end;
procedure LOG_LevelRestore; 			 begin LOG_Level(_LOG_OLD_Level); end;
procedure LOG_LevelColor(enab:boolean);	 begin _LOG_LevelColor:=enab; end;

function  LOG_GetEndMsg(comment:string):string;
var sh:string;
begin  
  if comment<>'' then sh:=comment else sh:=ApplicationName;
  LOG_GetEndMsg:=sh+' ended at '+FormatDateTime('dd.mm.yyyy hh:mm:ss.zzz',now)+', runtime was '+FormatDateTime('hh:mm:ss.zzz',Now-RPI_ProgramStartTime); 
end;

function  LOG_GetVersion(version:real):string; 		
begin LOG_GetVersion:=ApplicationName+' V'+Num2Str(version,0,3)+' build '+RPI_GetBuildDateTimeString; end;

function  MSK_Get8(bitnum:byte):byte; begin MSK_Get8:=(1 shl (bitnum and $07)); end; //IN:  bitnum 0-7

function  MSK_Get16_8(bitnum:byte; var idxofs:byte):byte;
//IN:  bitnum 0-15
begin
  idxofs:=((bitnum and $0f) shr 3); 
  MSK_Get16_8:=(1 shl (bitnum mod 8));
end;

function  MSK_Get64_8(bitnum:byte; var idxofs:byte):byte;
//IN:  bitnum 0-63
begin
  idxofs:=((bitnum and $3f) shr 3); 
  MSK_Get64_8:=(1 shl (bitnum mod 8));
end;

function  MSK_Get256_8(bitnum:byte; var idxofs:byte):byte;
//IN:  bitnum 0-255
begin
  idxofs:=((bitnum and $ff) shr 3); 
  MSK_Get256_8:=(1 shl (bitnum mod 8));
end;
  
procedure TL_prot_Init(var tlp:TL_prot_t);
begin
  with tlp do
  begin
	InitCriticalSection(TL_CS); 
	TL:=TStringList.create; 
	TL_modified:=false;
	Thread_InitStruct0(ThCtl);
  end; // with
end;
procedure TL_prot_Stop(var tlp:TL_prot_t);
begin
  with tlp do
  begin
    Thread_InitStruct(ThCtl);
    TL.free;   
	DoneCriticalSection(TL_CS); 
  end; // with
end;

function  LNX_ResolveIP2name(IP:string):string;
var _tl:TStringList; idx:longint; sh:string;
begin // todo
  sh:=IP;
  {$IFDEF UNIX} 
	_tl:=TStringList.create;
  	if (call_external_prog(LOG_NONE,'arp -a',_tl)=0) then
  	begin
	  idx:=SearchStringInListIdx(_tl,IP,1,0);
	  if (idx>=0) then
	  begin // found e.g. rpi3b_1w.abc.def.com (10.8.81.132) at <incomplete> on wlan0
		sh:=Trimme(Select_Item(_tl[idx],' (','',1),3);	// rpi3b_1w.abc.def.com 
		if (sh='') then sh:=IP;
	  end;
  	end;
  	_tl.free;
  {$ENDIF}
  LNX_ResolveIP2name:=sh;
end;
    
function  LNX_WDOG_Thread(ptr:pointer):ptrint;
var i64:int64; sh:string;
begin
//SAY(LOG_WARNING,'LNX_WDOG_Thread: start');
  try
  	with wdog do
  	begin
	  with ThreadCtrl do 
	  begin 
	  	TermThread:=false; ThreadRunning:=true;
  	  	repeat
      	  if not TermThread then 
      	  begin
		  	i64:=DeltaTime_in_ms(WDOGFire,now);
		  	if (i64<=retival_msec) then
		  	begin
		  	  sh:='LNX_WDOG_Thread: WDOG will fire within '+Num2Str(i64,0)+'msec';
		  	  if (i64>=1)	then LOG_Writeln(LOG_WARNING,sh)
		  	  				else LOG_Writeln(LOG_ERROR,	 sh);
		  	end;
          	delay_msec(retival_msec);
		  	if RetrigAsync then 
		  	begin
//		 	  SAY(LOG_WARNING,'WDOG: RetrigAsync');
			  LNX_WDOG(WDOG_Retrig);	// retrigger WDOG
		  	end;
	  	  end;
	  	until terminateProg or TermThread;
  	  	TermThread:=true; ThreadRunning:=false;
  	  end; // with
  	end; // with
  except
	On E_rpi_hal_Exception :Exception do writeln('LNX_WDOG_Thread: ',E_rpi_hal_Exception.Message);
  end;
//SAY(LOG_WARNING,'LNX_WDOG_Thread: end');
  EndThread;  
  LNX_WDOG_Thread:=0;
end;

procedure LNX_WDOG_Init(var struct:watchdog_struct_t);
var n:longint;
begin
  with struct do
  begin
	Hndl:=-1; 			devpath:=wdoc_path_c;	RetrigAsync:=true; 
	ival_sec:=15; 		retival_msec:=(ival_sec*1000) div 5; 
	Thread_InitStruct	(ThreadCtrl);
	LastBootStat:=0;
	NextTrigTime:=now;	SetTimeOut(WDOGFire,(ival_sec*1000));
	with info do
	begin
	  options:=0; 		firmware_version:=0;
	  for n:=0 to 31 do identity[n]:=$00;
	end;
  end; // with
end;

function  LNX_WDOG_Start:boolean;
(*	https://embeddedfreak.wordpress.com/2010/08/23/howto-use-linux-watchdog/
	https://github.com/binerry/RaspberryPi/blob/master/snippets/c/watchdog/wdt_test.c
	https://github.com/torvalds/linux/blob/master/include/uapi/linux/watchdog.h
	https://github.com/torvalds/linux/blob/master/include/uapi/asm-generic/fcntl.h *)
begin
  with wdog do
  begin
  	if (Hndl>=0) then LNX_WDOG(WDOG_Close);	// close old WDOG and reopen
  	LNX_WDOG(WDOG_Pause);	// retrig by Thread, not controlled by main prog (sync) 
  	Hndl:=fpOpen(devpath, (O_RDWR or O_NOCTTY));
  	if (Hndl<0) then
  	begin 
	  LOG_Writeln(LOG_ERROR,'LNX_WDOG['+Num2Str(Hndl,0)+']: can not open '+devpath); 
	  Hndl:=-1;
  	end 
  	else 
  	begin
	  ival_sec:=LNX_WDOG(WDOG_GTO);
(*	  if (wtim_ms=0) then wtim_ms:=((ival_sec*1000) div 3); // get wdog timeout
  	  if (wtim_ms=0) then wtim_ms:=2000;
  	  retival_msec:=wtim_ms; *)
	  SAY(LOG_INFO,'LNX_WDOG['+Num2Str(Hndl,0)+'/'+Num2Str(ival_sec,0)+'/'+Num2Str(retival_msec,0)+']: init succesful '+devpath);
  	end;
  	LNX_WDOG_Start:=(Hndl>=0);
  end; // with
end;

function  LNX_WDOG(wdog_action:t_rpimaintflags; p1:longint):longint;
var c:char='V'; res:longint; sh:string;
begin
  res:=-1; 
  with wdog do
  begin
	if (Hndl>=0) then
  	begin 
	  case wdog_action of
		WDOG_Close:	begin // disable and close watchdog device
					  LNX_WDOG(WDOG_Resume);
					  ThreadCtrl.TermThread:=true; // signal Thread terminate
					  if ((info.options and WDIOF_MAGICCLOSE)<>0) then
					  begin
			  		  	c:='V'; res:=fpwrite(Hndl,c,1);	// disable WDOG
			  		  	fpClose(Hndl);
			  		  	SAY(LOG_INFO,'LNX_WDOG['+Num2Str(Hndl,0)+'/'+Num2Str(res,0)+']: closed ');
			  		  end else LOG_Writeln(LOG_ERROR,'WDOG no support WDIOF_MAGICCLOSE');
			  		  Hndl:=-1;
					end;
		WDOG_Retrig:begin // retrigger WDOG
					  if ((info.options and WDIOF_KEEPALIVEPING)<>0) then
					  begin
			  		  {$R-} 
						if TimeElapsed(NextTrigTime,retival_msec) then
			  		 	begin
			  		 	  SetTimeOut(WDOGFire,(ival_sec*1000));
						  SAY(LOG_DEBUG,'LNX_WDOG[Retrig]: retrigger');
						  res:=fpIOCTL(Hndl, WDIOC_KEEPALIVE, nil);
//			  			  c:='W'; res:=fpwrite(Hndl,c,1);
						end;	
			  		  {$R+} 
			  		  end else LOG_Writeln(LOG_ERROR,'WDOG no support WDIOF_KEEPALIVEPING');
					end;
		WDOG_GTO:	begin  // get timeout (sec)
			  		  {$R-} 
						res:=fpIOCTl(Hndl, WDIOC_GETTIMEOUT, @ival_sec);
						SAY(LOG_DEBUG,'LNX_WDOG: timeout is '+Num2Str(ival_sec,0));
						if (res<>0) then
						begin
				  		  LOG_Writeln(LOG_ERROR,'LNX_WDOG[GTO]: '+Num2Str(fpGetErrno,0));
			 	  		  res:=-1;
			  			end
			  			else
			  			begin 
			  			  retival_msec:=(ival_sec*1000) div 5;
			  			  res:=ival_sec;
			  			end;
			  		  {$R+} 
					end;
		WDOG_STO:	begin // set timeout (sec)
					  if ((info.options and WDIOF_SETTIMEOUT)<>0) then
					  begin
			  		  {$R-} 
						if (p1>0) then ival_sec:=p1 else ival_sec:=15;
						SAY(LOG_DEBUG,'LNX_WDOG: timeout set '+Num2Str(ival_sec,0));
						res:=fpIOCTL(Hndl, WDIOC_SETTIMEOUT, @ival_sec);
						if (res<>0) then
						begin
				  		  LOG_Writeln(LOG_ERROR,'LNX_WDOG[STO]: '+Num2Str(fpGetErrno,0));
			 	  		  res:=-1;
			  			end 
			  			else 
			  			begin 
			  			  retival_msec:=(ival_sec*1000) div 5; 
			  			  res:=ival_sec; 
			  			end;
			  		  {$R+} 
			  		  end else LOG_Writeln(LOG_ERROR,'WDOG no support WDIOF_SETTIMEOUT');
		   			end;
		WDOG_BSTAT:	begin // Check if last boot is caused by watchdog
			  		  {$R-}
						res:=fpIOCTL(Hndl, WDIOC_GETBOOTSTATUS, @LastBootStat);
						if (res<>0) then
						begin
				  		  LOG_Writeln(LOG_ERROR,'LNX_WDOG[BSTAT]: '+Num2Str(fpGetErrno,0));
			 	   		  res:=-1;
						end
						else
						begin
				  		  res:=LastBootStat;
				  		  if (LastBootStat<>0) then 
							LOG_WRITELN(LOG_WARNING,'LNX_WDOG: Last boot was caused by: Watchdog');
						end;
			  		  {$R+}
					end;
		WDOG_GSup:	begin // WDIOC_GETSUPPORT		
(* options:0x00008180
wdctl:
Device:        /dev/watchdog
Identity:      Broadcom BCM2835 Watchdog timer [version 0]
Timeout:       15 seconds
Pre-timeout:    0 seconds
Timeleft:      14 seconds
FLAG           DESCRIPTION               STATUS BOOT-STATUS
KEEPALIVEPING  Keep alive ping reply          1           0
MAGICCLOSE     Supports magic close char      0           0
SETTIMEOUT     Set timeout (in seconds)       0           0		*)
			  		  {$R-}
						res:=fpIOCTL(Hndl, WDIOC_GETSUPPORT, @info);
						if (res<>0) then
						begin
				  		  LOG_Writeln(LOG_ERROR,'LNX_WDOG[GSup]: '+Num2Str(fpGetErrno,0));
			 	   		  res:=-1;
						end
						else
						begin
						  with info do
						  begin
							sh:=''; res:=0;
							while (res<=31) do
							begin
							  if (identity[res]<>$00) 
								then sh:=sh+char(identity[res]) else res:=31;
							  inc(res);
							end;
							SAY(LOG_INFO,'LNX_WDOG[GSup]: '+sh+' [version '+Num2Str(firmware_version,0)+'] opts:0x'+Hex(options,8));
							res:=options;
						  end; // with
						end;
			  		  {$R+}	
					end;	
		WDOG_Pause:	begin // pause
			  		  SAY(LOG_INFO,'LNX_WDOG: pause');
			  		  RetrigAsync:=true;
			  		  res:=0;
					end;
		WDOG_Resume:begin // resume
			  		  SAY(LOG_INFO,'LNX_WDOG: resume');
			  		  RetrigAsync:=false;
			  		  res:=0;
					end;
	  end; // case
	end;
  end; // with
  LNX_WDOG:=res;
end;
function  LNX_WDOG(wdog_action:t_rpimaintflags):longint; begin LNX_WDOG:=LNX_WDOG(wdog_action,0); end; 

function  LNX_ShellESC(s:string):string;
// $.*[\]^
var sh:string;
begin
  sh:=s;
  sh:=StringReplace(sh,'\','\\',[rfReplaceAll]);
  sh:=StringReplace(sh,'$','\$',[rfReplaceAll]);
  sh:=StringReplace(sh,'*','\*',[rfReplaceAll]);
  sh:=StringReplace(sh,'[','\[',[rfReplaceAll]);
  sh:=StringReplace(sh,']','\]',[rfReplaceAll]);
  sh:=StringReplace(sh,'^','\^',[rfReplaceAll]);
  sh:=StringReplace(sh,'.','\.',[rfReplaceAll]);
  sh:=StringReplace(sh,',','\,',[rfReplaceAll]);
  sh:=StringReplace(sh,'"','\"',[rfReplaceAll]);
  sh:=StringReplace(sh,'(','\(',[rfReplaceAll]);
  sh:=StringReplace(sh,')','\)',[rfReplaceAll]);
  LNX_ShellESC:=sh;
end;

function  LNX_ParLinEXIST(filnam,parstr:string):boolean;
// parstr IN: 'autostart=1'
// filnam IN: '/etc/hostapd/hostapd.conf'
var bool:boolean; n:longint; sh:string;
begin
  bool:=false;
  if (filnam<>'') and (parstr<>'') then 
  begin
    if (call_external_prog(LOG_NONE,'grep -c -F "'+parstr+'" "'+filnam+'"',sh)=0) then
      if Str2Num(Trimme(sh,3),n) then bool:=(n>0); // n linecount of parstr in filnam 
  end;
  LNX_ParLinEXIST:=bool;
end;

function  LNX_ParSET(filnam,parnam,parval:string):integer;
// filnam IN: '/etc/hostapd/hostapd.conf'
// parnam IN: 'autostart'
// parval IN: '1'
// OUT OK: >=0
var res:integer;
begin
  if (filnam<>'') and (parnam<>'') then 
  begin
    res:=call_external_prog(LOG_NONE,
      'sed -i -r "s/'+parnam+'[ ]*=.*/'+parnam+'='+parval+'/g" "'+filnam+'"');
  end else res:=-1;
  LNX_ParSET:=res;
end;

function  LNX_ParGET(filnam,parnam:string; var parval:string):integer;
// filnam IN:  '/etc/hostapd/hostapd.conf'
// parnam IN:  'autostart'
// parval OUT: '1'
var res:integer;
begin
  if (filnam<>'') and (parnam<>'') then 
  begin
//	res:=call_external_prog(LOG_NONE,'grep -sF "'+parnam+'=" '+filnam+' | sed "s/'+parnam+'=//g"',parval);
    res:=call_external_prog(LOG_NONE,'grep -sF "'+parnam+'=" '+filnam,parval);
    if (res=0) then
    begin
	  if (parval<>'') then
      begin
		parval:=StringReplace(parval,parnam+'=','',[]);
      end else res:=-3;	// no para line
    end else res:=-2;	// file not exist
  end else res:=-1;		// file or para not given
  LNX_ParGET:=res;
end;

procedure LNX_sudo(sudouse:boolean); 
begin if sudouse then sudo:='sudo ' else sudo:=''; end;
function  LNX_sudo:boolean; begin LNX_sudo:=(Trimme(sudo,3)<>''); end;

procedure LNX_ADD2Crontab(cmd:string);
var sh:string;
begin
  if (cmd<>'') then
  begin
	sh:=sudo+'(crontab -l; echo "'+LNX_ShellESC(cmd)+'";) | crontab -';
	call_external_prog(LOG_NONE,sh,sh);
  end;
end;

function  LNX_SetDateTimeUTC(utc:TDateTime):boolean;
var cmd:string;
begin
  cmd:='timedatectl set-time '''+FormatDateTime('yyyy-mm-dd',utc)+' '+FormatDateTime('hh:nn:ss',utc)+'''';
  LNX_SetDateTimeUTC:=(call_external_prog(LOG_NONE,cmd)=0);
end;

function  LNX_GetTZList(ts:TStringList):integer;
var res:integer;
begin
  res:=call_external_prog(LOG_NONE,'timedatectl list-timezones',ts);
  if (res=0) then ts.insert(0,'Etc/UTC') else ts.clear;
  LNX_GetTZList:=res;
end;

function  LNX_GetRandomAccessToken(typ:longint):string;
// openssl rand -base64 12
// openssl rand -hex 12
const cmd1='openssl rand -base64 12'; cmd2='date | md5sum'; 
var res:integer; token:string;
begin
  res:=call_external_prog	(LOG_INFO,cmd1,token);
  token:=GetAlphaNumChar(token);
  if (res<>0) or (token='') then 
  begin
    res:=call_external_prog	(LOG_INFO,cmd2,token);
    token:=GetAlphaNumChar(token);
    if (res<>0) or (token='') then 
	  token:=FormatDateTime('YYYYMMDDhhmmss',now); // last chance
  end;
  LNX_GetRandomAccessToken:=token;
end;

function  LNX_chmod(filename:string; mode:TMode):cint;
var res:cint;
begin
  if FileExists(filename) then
  begin
	res:=0;
	{$IFDEF WINDOWS}
	  res:=call_external_prog(LOG_NONE,'chmod '+Hex(mode,3)+' '+filename);
	{$ELSE}
	  res:=fpChmod(filename,mode);
	{$ENDIF}
  end else res:=-1;
  LNX_chmod:=res;
end;

function  LNX_chowngrp(filename:string; owner,group:string):integer;
var res:integer; cmd:string;
begin
  res:=0;
  	res:=-1;
	if FileExists(filename) then
	begin
	  cmd:='';
	  if (owner<>'') then cmd:=cmd+'chown '+owner+' '+filename;
	  if (owner<>'') and (group<>'') then cmd:=cmd+' ; ';
	  if (group<>'') then cmd:=cmd+'chgrp '+group+' '+filename;
      res:=call_external_prog(LOG_NONE,cmd);
    end;
  LNX_chowngrp:=res;
end;

procedure LNX_GetUsrPwdString(StrList:TStringList; pwdfile,usrlst:string; carveflds:longint);
// pwdfile: /etc/shadow 
// usrlst:  admin:|pi:
var n:longint;
begin
  if (Trimme(usrlst,3)<>'') and (pwdfile<>'') then
	call_external_prog(LOG_NONE,'grep -E "'+usrlst+'" "'+PrepFilePath(pwdfile)+'"',StrList);
  if (carveflds>0) then
  begin
	for n:= 1 to StrList.count do
	  StrList[n-1]:=Select_LeftItems(StrList[n-1],':','',carveflds);
  end;
end;

function  LNX_UpdPwdFile(pwdfile,usr,pwd:string):integer;
// maintain usr:pwd files (e.g. for lighthttpd webserver)
var res:integer; _idx:longint; _tl:TStringList;
begin
  res:=-1;
  if (pwdfile<>'') and (usr<>'') then
  begin
	_tl:=TStringList.create;
	if FileExists(pwdfile) then
	begin
	  _idx:=SearchStringInListIdx(_tl,usr+':',1,0);
	  if (_idx>=0) then _tl.delete(_idx);
	end;
	_tl.add(usr+':'+pwd);
	if StringList2TextFile(pwdfile,_tl) then res:=0;
	_tl.free;
  end;
  LNX_UpdPwdFile:=res;
end;

function  LNX_ChkUsrPwdValid(usr,pwd,pwddefault:string):integer;
// IN: usr,password // access to /etc/shadow
// OUT -2:mkpasswd  mkpasswd not installed or returned an error -1:not valid 0:valid 1:pwd=pwddefault
// mkpasswd is part of paket whois -> apt-get install whois
const ma=10;
var res:integer; i,j:longint; dt:TDateTime; tlh:TStringList; 
	sh,salt,algo,cmd,cmd0:string; arr:array[1..ma] of string;
begin
  res:=-1;
  {$IFDEF UNIX}
  if (usr<>'') and (pwd<>'') then
  begin
	tlh:=TStringList.create;
  	res:=call_external_prog(LOG_ERROR,sudo+'cat '+LNX_ShadowFile+' | grep '+usr+':',tlh);  	
  	if (res=0) and (tlh.count>0) then
  	begin
      sh:=tlh[0]; for i:=1 to ma do arr[i]:=Select_Item(sh,':','',i);
      if (arr[2]<>'!') and (arr[2]<>'*') then
      begin
      	algo:=Select_Item	(arr[2],'$','',2); sh:=algo;
      	salt:=Select_Item	(arr[2],'$','',3);
    					 	 algo:='DES';
      	if sh='1' 		then algo:='md5';
      	if sh='2a' 		then algo:='Blowfish';
      	if sh='2y' 		then algo:='Blowfish';
      	if sh='5' 		then algo:='sha-256';
      	if sh='6' 		then algo:='sha-512';
      	if sh=algo		then res:=-1;
      end else res:=-1; 
      if arr[1]<>usr	then res:=-1;
      if Str2Num(arr[8],j) then
      begin // test account deactivation
      	dt:=now; dt:=IncDay(EncodeDate(1970,1,1),j);
      	if dt<=now then res:=-1;
      end;
//	  writeln('salt:',salt); writeln('algo:',algo); for i:=1 to 5 do writeln(i,' ',arr[i]);
	  if (res=0) then
	  begin
		tlh.clear; 
//		if (pwd='') then pwd:='-s \<\<\< /dev/null';
	  	cmd0:=sudo+'mkpasswd -m '+algo+' -S '+salt+' ';
	  	cmd:=				cmd0+pwd;
	  	if (pwddefault<>'') then cmd:=cmd+' ; '+cmd0+pwddefault;	  	
	  	cmd:=cmd+' 2>&1';
	  	res:=call_external_prog(LOG_ERROR,cmd,tlh);  		  
//	  	SAY(LOG_INFO,'LNX_ChkUsrPwdValid:'+Num2Str(res,0)+' '+Num2Str(tlh.count,0)+' '+cmd); SAY_TL(LOG_INFO,tlh);
		if (res=0) then
		begin
	  	  if (tlh.count>0) then
		  begin
	    	if (tlh[0]=arr[2]) then 
	    	begin
	    	  if ((tlh.count>=2) and (tlh[0]=tlh[1])) then res:=1;	// default pwd used
	    	end else res:=-1;	// different pwd
(*		 	SAY(LOG_INFO,'LNX_ChkUsrPwdValid[infos '+Num2Str(res,2)+'/'+Num2Str(tlh.count,0)+']: usr: '+usr+' pwd: '+pwd+' pwddflt: '+pwddefault);
			SAY(LOG_INFO,'LNX_ChkUsrPwdValid[shadowDB]:   '+arr[2]);
			SAY(LOG_INFO,'LNX_ChkUsrPwdValid[PWDgiven]:   '+tlh[0]); 
			SAY_TL(LOG_INFO,tlh);  *)
	  	  end else begin LOG_Writeln(LOG_ERROR,'LNX_ChkUsrPwdValid[4]: '+Num2Str(res,0)+' no output '+cmd); res:=-2; end;
	  	end else begin LOG_Writeln(LOG_ERROR,'LNX_ChkUsrPwdValid[3]: '+Num2Str(res,0)+' mkpasswd erroneous call'); res:=-2; end;
	  end else begin LOG_Writeln(LOG_ERROR,'LNX_ChkUsrPwdValid[2]: '+Num2Str(res,0)+' unknown algo'); res:=-1; end;
	end else begin LOG_Writeln(LOG_ERROR,'LNX_ChkUsrPwdValid[1]: '+Num2Str(res,0)+' no access to '+LNX_ShadowFile); res:=-1; end;  
	tlh.free;
  end else begin LOG_Writeln(LOG_ERROR,'LNX_ChkUsrPwdValid[0]: '+Num2Str(res,0)+' empty usr/pwd '); res:=-1; end;  
  {$ENDIF}
  LNX_ChkUsrPwdValid:=res;
end;

function  LNX_ChgUsrPwd(usr,usrreq,pwd,pwd2,pwddflt,pwdold:string; PWD_OLDsameNEW:boolean; var msg:string):integer;
var res:integer; tlh:TStringList; cmd:string;
begin
  res:=-1; tlh:=TStringList.create; 
  if (usr=usrreq) then
  begin
    if (pwd=pwd2) then
    begin
	  if (pwd<>pwddflt) then
      begin
        {$IFDEF UNIX}
        if (pwdold='') then res:=0 else res:=LNX_ChkUsrPwdValid(usr,pwdold,'');
        if (res=0) then
        begin
    	  if (LNX_ChkUsrPwdValid(usr,pwd,pwddflt)<0) or (PWD_OLDsameNEW) then
          begin
//    	 	cmd:='echo '''+usr+':'+pwd+''' | '+sudo+'chpasswd'; // does not work
		  	cmd:=sudo+'echo -e "'+pwd+'\n'+pwd+'\n" | passwd '+usr;
    	  	res:=call_external_prog(LOG_NONE,cmd,tlh);
			if (res<>0) then 
			begin
			  LOG_Writeln(LOG_ERROR,'LNX_ChgUsrPwd: can not set pwd for usr: '+usr+' '+Num2Str(res,0));
			  LOG_ShowStringList(LOG_ERROR,tlh);
			  res:=-6;
			end else LNX_UsrAuthModDateTime:=GetFileAge(LNX_ShadowFile);	// upd modification date of shadow file
    	  end else res:=-5; // newpwd=oldpwd
    	end else res:=-7; // wrong old pwd
		{$ELSE}
		  res:=-8; // not for windows
		{$ENDIF}
//		SAY(LOG_INFO,'LNX_ChgUsrPwd: '+Num2Str(res,0)+' set new pwd for usr:'+usr+' pwd:'+pwd);
	  end else res:=-4; 
	end else res:=-3; 
  end else res:=-2; 
  case res of
  	-8: msg:='no unix system';
  	-7: msg:='wrong password';
    -6: msg:='can not set pwd';
    -5: msg:='same pwd not allowed';
	-4: msg:='default pwd not allowed'; 
	-3: msg:='passwords do not match'; 
	-2: msg:='wrong usr'; 
	 0: msg:='password changed'; 
   else msg:='unknown error';
  end; // case
  if res=0	then SAY(		 LOG_NOTICE,'LNX_ChgUsrPwd: '+msg)
  			else LOG_Writeln(LOG_ERROR,	'LNX_ChgUsrPwd: '+msg);
  tlh.free;
  LNX_ChgUsrPwd:=res;
end;
function  LNX_ChgUsrPwd(usr,pwd:string; var msg:string):integer;
begin LNX_ChgUsrPwd:=LNX_ChgUsrPwd(usr,usr,pwd,pwd,pwd+'x','',true,msg); end;

function  LNX_RemoveOldFiles(path2files:string; days:longint):integer;
// e.g. LNX_RemoveOldFiles('/path/to/files*',5);
// delete files older than 5 days
// find /path/to/files* -mtime +5 -exec rm {} \;
var res:integer; cmd,sh:string;
begin
  if DirectoryExists(Get_Dir(path2files)) then
  begin
    cmd:=sudo+'find '+path2files+' -mtime '+Num2Str(days,0)+' -exec rm {} \;';
//	SAY(LOG_INFO,'LNX_RemoveOldFiles['+Num2Str(days,0)+'days]: '+cmd);
    res:=call_external_prog(LOG_NONE,cmd,sh); res:=0;
  end else res:=-1; 
  LNX_RemoveOldFiles:=res;
end;

function  LNX_CertFormatTyp(certtyp:Cert_Type_t):string;
var sh:string;
begin
  sh:=StringReplace(GetEnumName(TypeInfo(Cert_Type_t),Ord(certtyp)),'CT_','',[rfReplaceAll,rfIgnoreCase]);
  LNX_CertFormatTyp:=sh;
end;

function  LNX_CertIDget(filnam:string; certtyp:Cert_Type_t; idouttyp:Cert_Type_t; var id:string):boolean;
// LNX_CertSerialGET('mycert.pem',sha1,id)
var ok:boolean; cmd,cmd2,typs2,typs:string;
begin
  if FileExists(filnam) then
  begin// openssl x509 -in mycert.pem -noout -serial
    typs2:=lowercase(LNX_CertFormatTyp(idouttyp)); cmd2:='';
	cmd:='openssl '+lowercase(LNX_CertFormatTyp(certtyp))+' -in "'+filnam+'" -noout';
	case idouttyp of
		CT_md5:		typs:='MD5 Fingerprint';
		CT_sha1:	typs:='SHA1 Fingerprint';
		CT_sha256:	typs:='SHA256 Fingerprint';
		CT_serial:	typs:='serial';
		CT_modulus:	typs:='Modulus';
		CT_modmd5:	begin 
					  typs2:=lowercase(LNX_CertFormatTyp(CT_modulus));
					  cmd2:=' | sed "s/Modulus=//g" | sed "s/://g" | openssl md5'; 
					  typs:='(stdin)'; 
					end;
	end; // case
	cmd:=cmd+' -'+typs2+cmd2+' | sed "s/'+typs+'=//g" | sed "s/://g"';
//writeln(cmd);
    call_external_prog(LOG_NONE,cmd,id);
    id:=GetHexChar(id);
	ok:=(id<>'');
  end else ok:=false;
  LNX_CertIDget:=ok;
end;

procedure LNX_CertIDtest;
var ok:boolean; hashpub,hashpriv:string;
begin
  SAY(LOG_INFO,'Check validity of .pem and .key file with md5 hash of both moduli');
  ok:=(	LNX_CertIDget(cert0_key_c,		CT_rsa, 	CT_modmd5,	hashpriv) and
  		LNX_CertIDget(cert0_crtORpem_c,	CT_x509,	CT_modmd5,	hashpub) );
  if ok then
  begin
	ok:=(hashpriv=hashpub);
	SAY(LOG_INFO,'LNX_CetIDtest ok:'+Bool2Str(ok));
	SAY(LOG_INFO,hashpriv+' ('+cert0_key_c+')');
	SAY(LOG_INFO,hashpub+ ' ('+cert0_crtORpem_c+')');
  end else LOG_Writeln(LOG_ERROR,'LNX_CetIDtest: files not accessable '+cert0_key_c+' or '+cert0_crtORpem_c);
end;

procedure LNX_CertInit(var certstruct:cert_t);
begin
  with certstruct do
  begin
    ok:=false; filnam:=''; id:='';
  end; // with
end;

procedure LNX_CertShow(lvl:T_ErrorLevel; var certstruct:cert_t);
begin
  with certstruct do
  begin
    if (certtyp=CT_Path)
  	  then SAY(lvl,Get_FixedStringLen(desc+'Path:',15,false)+filnam)
  	  else SAY(lvl,Get_FixedStringLen(desc+':',15,false)+	 filnam+
  	  	' id:'+id+' typ:'+LNX_CertFormatTyp(certtyp));
  end; // with
end;

procedure LNX_CertPackShow(lvl:T_ErrorLevel; var certpack:cert_pack_t);
begin
  with certpack do
  begin
  	SAY(lvl,Get_FixedStringLen('CertInfo['+Num2Str(idx,0)+']:',15,false)+desc+' ok:'+Bool2YN(ok)+' pwdset:'+(Bool2YN(pwd<>'')+' packtyp:'+LNX_CertFormatTyp(packtyp)));
  	LNX_CertShow(lvl,cert[CertPrivKey]);
  	LNX_CertShow(lvl,cert[CertPublic]);
  	LNX_CertShow(lvl,cert[CertCombined]);
  	LNX_CertShow(lvl,cert[CertCA]);
  end; // with
end;

function  LNX_CertDir(var certstruct:cert_t; certfil:string; certtype:Cert_Type_t):boolean;
begin
  LNX_CertInit(certstruct);
  with certstruct do
  begin
  	filnam:=certfil; certtyp:=certtype; ok:=true; id:='';
	LNX_CertDir:=ok;
  end; // with
end;

function  LNX_CertReg(var certstruct:cert_t; certfil:string; certtype:Cert_Type_t):boolean;
begin
  LNX_CertInit(certstruct);
  with certstruct do
  begin
  	filnam:=certfil; certtyp:=certtype;
	ok:=LNX_CertIDget(filnam,certtyp,CT_modmd5,id);
	if not ok then id:='';
	LNX_CertReg:=ok;
  end; // with
//LNX_CertShow(LOG_INFO,certstruct);
end;

procedure LNX_CertInitPack(var certpack:cert_pack_t; num:longint);
var n:longint;
begin
  for n:=CertPublic to CertCombined do 
  begin
    LNX_CertInit(	certpack.cert[n]);
    case n of
      CertPublic:	certpack.cert[n].desc:='PublicCert';
      CertPrivKey:	certpack.cert[n].desc:='PrivateKey';
      CertCA:		certpack.cert[n].desc:='CertAuth';
      CertCombined: certpack.cert[n].desc:='CertCombined';
      else			LOG_Writeln(LOG_ERROR, 'LNX_CertInitPack: invalid idx '+Num2Str(n,0));
    end; // case
  end;
  certpack.desc:=''; certpack.pwd:=''; certpack.ok:=false; certpack.idx:=num;
end;

function  LNX_CertStartPack(var certpack:cert_pack_t; descr,pubcertfil,privkeyfil,cacertfil,combinedfil,passwd:string; certpacktyp:Cert_Type_t):boolean;
// https://gist.github.com/BlueT/ee521743fa0da703af68f37ac0f63a90
begin
  with certpack do
  begin
	LNX_CertInitPack(certpack,idx);
	desc:=descr; pwd:=passwd;	packtyp:=certpacktyp;

//  create a combined .pem file for e.g. lighthttp
	if (combinedfil<>'') and (not FileExists(combinedfil)) and
	  	FileExists(privkeyfil) and (GetFileSize(privkeyfil)>0) and
	  	FileExists(pubcertfil) and (GetFileSize(pubcertfil)>0) then
	  call_external_prog(LOG_NONE,'cat '+privkeyfil+' '+pubcertfil+' > '+combinedfil+
	  							  ' ; chmod 640 '+combinedfil);

	LNX_CertReg(				cert[CertPublic],	pubcertfil,	CT_x509);
	LNX_CertReg(				cert[CertPrivKey],	privkeyfil,	CT_rsa);
	LNX_CertReg(				cert[CertCombined],	combinedfil,CT_Combined);
	if (cacertfil<>'') then
	begin
	  if not IsDir(cacertfil) then 
	  begin
		if FileExists(cacertfil) and (GetFileSize(cacertfil)>0)
		  then LNX_CertReg(		cert[CertCA],		cacertfil,	CT_x509)
		  else cert[CertCA]:=	cert[CertPublic];
	  end else LNX_CertDir(		cert[CertCA],		cacertfil,	CT_Path);
	end else cert[CertCA]:=		cert[CertPublic];
	ok:=(cert[CertPublic].ok and cert[CertPrivKey].ok and cert[CertCA].ok);
//	ok:=(cert[CertPublic].id=cert[CertPrivKey].id);
	LNX_CertStartPack:=ok;
  end; // with
end;

// https://linuxconfig.org/easy-way-to-encrypt-and-decrypt-large-files-using-openssl-and-linux
function  LNX_DecryptFile(filprivkey,filnam,ext:string; flags:s_rpimaintflags):integer;
// e.g. LNX_DecryptFile('/etc/ssl/private/ssl-cert-snakeoil.key','supportfile_123.tgz','ssl',[]);
// openssl smime -decrypt -binary -in supportfile_123.tgz.ssl -out supportfile_123.tgz -inform DEM -inkey /etc/ssl/private/ssl-cert-snakeoil.key
var res:integer; cmd,sh:string;
begin
  res:=-1;
  if FileExists(filnam+'.'+ext) and FileExists(filprivkey) then
  begin
	cmd:=''; if (ext='') then ext:=LNX_CertFormatTyp(CT_ssl);
	cmd:=cmd+	'openssl smime -decrypt -binary'+
						' -in '+				filnam+'.'+ext+' '+
						' -out '+				filnam+' '+
						' -inform DEM -inkey '+	filprivkey;
	res:=call_external_prog(LOG_NONE,cmd,sh); res:=0;
	if (res=0) then res:=GetFileSize(filnam) else res:=-1;
  	if (res>0) then res:=0;	// to set LOG notice
  end else LOG_Writeln(LOG_ERROR,'LNX_DecryptFile: files not exist '+filnam+'.'+ext+' '+filprivkey);
  LNX_DecryptFile:=res;
end;

function  LNX_EncryptFile(filpubkey,filnam,ext:string; flags:s_rpimaintflags):integer;
// e.g. LNX_EncryptFile('/etc/ssl/certs/ssl-cert-snakeoil.pem','supportfile_123.tgz','ssl',[]);
// openssl smime -encrypt -binary -aes-256-cbc -in supportfile_123.tgz -out supportfile_123.tgz.ssl -outform DER /etc/ssl/certs/ssl-cert-snakeoil.pem
var res:integer; cmd,sh:string;
begin
  res:=-1;
  if FileExists(filnam) and FileExists(filpubkey) then
  begin
	cmd:=''; if (ext='') then ext:=LNX_CertFormatTyp(CT_ssl);
	cmd:=cmd+	'openssl smime -encrypt -binary -aes-256-cbc'+
						' -in '+			filnam+
						' -out '+			filnam+'.'+ext+
						' -outform DER '+	filpubkey;
	res:=call_external_prog(LOG_NONE,cmd,sh); res:=0;
//	SAY(LOG_INFO,'LNX_EncryptFile:'+cmd+':'+Num2Str(res,0)+':'+sh+':');
	if (res=0) then res:=GetFileSize(filnam+ext) else res:=-1;
  	if (res>0) then res:=0;	// to set LOG notice
  end else LOG_Writeln(LOG_ERROR,'LNX_EncryptFile: files not exist '+filnam+' '+filpubkey);
  LNX_EncryptFile:=res;
end;

function  LNX_LinkFile(filnam,linknam:string):integer;
var res:integer; cmd:string;
begin
  if (linknam<>'') then
  begin
	if (filnam<>'') and (filnam<>linknam) and (FileExists(filnam))
	  then cmd:='ln -s "'+	filnam+'" "'+linknam+'"'
	  else cmd:='rm "'+	linknam+'"';
	res:=call_external_prog(LOG_NONE,cmd);
//SAY(LOG_WARNING,Num2Str(res,0)+':'+cmd+':'+filnam+':'+linknam);
  end else res:=-1;
  LNX_LinkFile:=res;
end;

function  LNX_GetNewestFile(filnampat:string):string;
// filnampat: /var/lib/BASIS/pump/bck/bckcfg_0000000012345_*
var _tl:TStringList; sh:string;
begin
  _tl:=TStringList.create;
  call_external_prog(LOG_NONE,'ls -1r '+filnampat,_tl);
  if (_tl.count>0) then
  begin
	if ((_tl[0]<>'') and FileExists(_tl[0])) then sh:=_tl[0];
  end else sh:='';
  _tl.free;
//writeln('LNX_GetNewestFile:',filnampat,':',sh);
  LNX_GetNewestFile:=sh;
end;

function  LNX_tarRST(target,fillst:string; flags:s_rpimaintflags):longint;
// restore tar --keep-newer-files -xzvf bck_<snr>.tgz -C / 
var res:longint; cmd:string;
begin
  res:=-1; 
  fillst:=PrepFilePath(Trimme(fillst,3)); 
  target:=PrepFilePath(Trimme(target,3));
  if (fillst<>'') and (FileExists(fillst)) then
  begin
    cmd:='';
	if (target='') then target:=PrepFilePath(c_tmpdir+'/tmp');
	if (UpdNewerOnly	IN flags)		then cmd:=cmd+'--keep-newer-files ';
	cmd:=cmd+'-x';
	if (Pos('.GZ', Upper(fillst))>0) 	or
	   (Pos('.TGZ',Upper(fillst))>0)	then cmd:=cmd+'z';
	if (UpdVerbose 		IN flags)		then cmd:=cmd+'v';
	cmd:='tar '+cmd+'f '+fillst+' -C '+target;
	if not (UpdVerbose	IN flags)		then cmd:=cmd+' >/dev/null 2>&1';
//	SAY(LOG_INFO,'LNX_tarRST: '+cmd);
	res:=call_external_prog(LOG_NONE,cmd); res:=0;
	if (res>=0) then res:=0 else res:=-1;
//  if (res=0) then res:=GetFileSize(fillst) else res:=-1;
  end;
  LNX_tarRST:=res;
end;

function  LNX_tarSAV(target,fillst:string; flags:s_rpimaintflags):longint;
var res:longint; cmd,tflg,ddir,sh:string;
begin
  if not (UpdNoWDOGprevent IN flags) then LNX_WDOG(WDOG_Pause);   // pause
  ddir:=PrepFilePath(AppDataDir_c+'/'+ApplicationName);
  if (fillst='') then fillst:=ddir+'/'+ApplicationName+'.ini';
  if (target='') then target:=PrepFilePath(c_tmpdir+'/bck_'+RPI_snr);
  
//adjust extension will exclusively determined by flags
  target:=StringReplace(target,'.gz','',	[rfReplaceAll,rfIgnoreCase]);
  target:=StringReplace(target,'.tgz','',	[rfReplaceAll,rfIgnoreCase]);
  target:=StringReplace(target,'.tar','',	[rfReplaceAll,rfIgnoreCase]);
  
  if (not (UpdNoCreateDir IN flags)) or DirectoryExists(Get_Dir(target)) then
  begin
    cmd:='';  
    if not	(UpdNoCreateDir IN flags) then cmd:=cmd+'mkdir -p '+Get_Dir(target)+' ; ';
    
    tflg:='';
    if not	(UpdNoZIP 		IN flags) then 
    begin 
	  tflg:=tflg+'z';	target:=target+'.tgz';
    end else 			target:=target+'.tar';

    if 		(UpdFollowLink 	IN flags) then		 tflg:=tflg+'h';
    if 		(UpdVerbose 	IN flags) then		 tflg:=tflg+'v';
    if		(UpdVerify 		IN flags) and
	 		(UpdNoZIP		IN flags) then		 tflg:=tflg+'W'; // tar: Cannot verify compressed archives
    
	cmd:=cmd+	'tar -c'+tflg+'f '+	target
  			 		+' --exclude='+		target
  					+' '+				fillst;
  	if not	(UpdVerbose 	IN flags) then cmd:=cmd+' >/dev/null 2>&1';
//	SAY(LOG_INFO,'LNX_tar: '+cmd);
  	res:=call_external_prog(LOG_NONE,cmd,sh); res:=0;
  	if (res=0) then res:=GetFileSize(target) else res:=-1;
  	
  	if (UseENCrypt IN flags) then
  	begin
	  if (res>0) then
	  begin
		with CertPack[0] do
		begin
		  if (CertPack[0].ok) then
		  begin
			res:=LNX_EncryptFile(
					cert[CertPublic].filnam,
					target,
					cert[CertPublic].id+'.'+LNX_CertFormatTyp(packtyp),
					flags);
		  end else LOG_Writeln(LOG_ERROR,'LNX_tar: CertPack[0] not initialized');
	  	end; // with
	  end else LOG_Writeln(LOG_ERROR,'LNX_tar: can no encrypt file, filesize not ok');
  	end;
  	
  	if (res>0) then res:=0;	// to set LOG notice
  end else LOG_Writeln(LOG_ERROR,'LNX_tar: target dir does not exist '+Get_Dir(target));
  if not (UpdNoWDOGprevent IN flags) then LNX_WDOG(WDOG_Resume);  // resume
  LNX_tarSAV:=res;
end;

procedure MinMaxAdj(var value:real; valmin,valmax:real);
begin
  if not IsNaN(value) then
  begin
	if not IsNaN(valmin) then if (value<valmin) then value:=valmin;
  	if not IsNaN(valmax) then if (value>valmax) then value:=valmax;
  end
  else
  begin
	if not IsNaN(valmin) then value:=valmin;
  end;
end;

function  Limits(var value:longint; minvalue,maxvalue:longint):longint;
begin if value>maxvalue then value:=maxvalue; if value<minvalue then value:=minvalue; Limits:=value; end;
function  Limits(var value:longword; minvalue,maxvalue:longword):longword;
begin if value>maxvalue then value:=maxvalue; if value<minvalue then value:=minvalue; Limits:=value; end;
function  Limits(var value:real; minvalue,maxvalue:real):real;
begin if value>maxvalue then value:=maxvalue; if value<minvalue then value:=minvalue; Limits:=value; end;

procedure MinMax(value:longint; var minvalue,maxvalue:longint);
begin if value>maxvalue then maxvalue:=value; if value<minvalue then minvalue:=value; end;
procedure MinMax(value:longword; var minvalue,maxvalue:longword);
begin if value>maxvalue then maxvalue:=value; if value<minvalue then minvalue:=value; end;
procedure MinMax(value:real; var minvalue,maxvalue:real);
begin 
  if not IsNan(value) then
  begin
	if IsNaN(maxvalue) 
	  then maxvalue:=value
	  else if value>maxvalue then maxvalue:=value; 
	if IsNaN(minvalue) 
	  then minvalue:=value
	  else if value<minvalue then minvalue:=value;
  end;
end;

procedure STAT_Init(var stats:STAT_struct_t; numoldval:word);
var i:longint;
begin
  with STATS do
  begin
    arr_siz:=numoldval;
	tim_avg:=0;
	ist_val:=0;
	old_val:=ist_val;
	val_avg:=ist_val;
	old_avg:=val_avg;
	for i:=0 to arr_siz do 
	begin
	  with aold[i-1] do
	  begin
	  	_val:=	ist_val;
	  	_valtimd:=0;
	  end; // with
	end; // for
	old_val_cnt:=0;
	dif_val_pms:=0;
  end; // with
end;

procedure STAT_Calc(var stats:STAT_struct_t; newval:real; tim_us:int64);
var i,cntok:integer;
begin
  with STATS do
  begin
	old_val:=				ist_val; 
	old_avg:=				val_avg;
	ist_val:=				newval;
	aold[-1]._val:=			val_avg;
	aold[old_val_cnt]._val:=ist_val; 
	aold[-1]._valtimd:=		round(tim_avg);
	aold[old_val_cnt]._valtimd:=tim_us;
	val_avg:=0; tim_avg:=0; cntok:=0;
	
	for i:= 1 to arr_siz do 
	begin
	  if aold[i-1]._valtimd>0 then
	  begin 
		val_avg:=val_avg+aold[i-1]._val;
	  	tim_avg:=tim_avg+aold[i-1]._valtimd; 
		inc(cntok); 
	  end;
	end;
	if cntok=0 	then 
	begin
	  val_avg:=ist_val;
	  tim_avg:=aold[old_val_cnt]._valtimd;
	end 
	else 
	begin
	  val_avg:=			val_avg/cntok;
	  tim_avg:=round(	tim_avg/cntok);
	end;
//	if aold[old_val_cnt]._valtimd<>0 
//	  then dif_val_pms:=(val_avg-aold[-1]._val)/(aold[old_val_cnt]._valtimd/1000)
//	  else dif_val_pms:=0;
	if (tim_avg<>0) and (cntok>1)
	  then dif_val_pms:=(val_avg-aold[-1]._val)/(tim_avg/1000)
	  else dif_val_pms:=0;
	  	    
	inc(old_val_cnt); if old_val_cnt>=arr_siz then old_val_cnt:=0;
//	old_val_cnt:=(old_val_cnt+1) mod arr_siz;
  end; // with
end;

function  Str2Bool(s:string; var ein:boolean):boolean;
var ok:boolean;
begin
  ok:=false;
  if Pos(Upper(s),yes_c) >0 then begin ok:=true; ein:=true;  end;
  if Pos(Upper(s),nein_c)>0 then begin ok:=true; ein:=false; end;
  Str2Bool:=ok;
end;
function  Str2Bool(s:string):boolean; begin Str2Bool:=(Pos(Upper(s),yes_c)>0); end;

function  Bool2Num(b:boolean) : byte;		 begin if b then Bool2Num:=1		else Bool2Num:=0;		end;
function  Bool2Dig(b:boolean) : string; 	 begin if b then Bool2Dig:='1'		else Bool2Dig:='0';      end;
function  Bool2LVL(b:boolean) : string; 	 begin if b then Bool2LVL:='H'		else Bool2LVL:='L';      end;
function  Bool2Str(b:boolean) : string; 	 begin if b then Bool2Str:='TRUE'	else Bool2Str:='FALSE';  end;
function  Bool2Swc(b:boolean) : string; 	 begin if b then Bool2Swc:='ON'		else Bool2Swc:='OFF';    end;
function  Bool2OC (b:boolean) : string; 	 begin if b then Bool2OC:='OPEN'	else Bool2OC:='CLOSE';   end;
function  Bool2YN (b:boolean) : string; 	 begin if b then Bool2YN:='YES'		else Bool2YN:='NO';      end;
function  Bool2YNS(b:boolean) : string; 	 begin if b then Bool2YNS:='Y'		else Bool2YNS:='N';      end;
function  Bool2EA (b:boolean) : string; 	 begin if b then Bool2EA:='ENABLED'	else Bool2EA:='DISABLED';end;
function  Bool2eas(b:boolean) : string; 	 begin if b then Bool2eas:='enable' else Bool2eas:='disable';end;
function  Bool2UpDown(b:boolean):string; 	 begin if b then Bool2UpDown:='up'	else Bool2UpDown:='down';end;

function  Num2Str(num:int64;lgt:byte):string;    var s:string; begin str(num:lgt,s); Num2Str:=s; end;
function  Num2Str(num:longint;lgt:byte):string;  var s:string; begin str(num:lgt,s); Num2Str:=s; end;
function  Num2Str(num:longword;lgt:byte):string; var s:string; begin str(num:lgt,s); Num2Str:=s; end;
function  Num2Str(num:real;lgt,nk:byte):string;  var s:string; begin str(num:lgt:nk,s);Num2Str:=s; end;
function  Num2Str(num:int64):string;   		begin Num2Str:=Num2Str(num,0); end;
function  Num2Str(num:longint):string; 		begin Num2Str:=Num2Str(num,0); end;
function  Num2Str(num:longword):string;		begin Num2Str:=Num2Str(num,0); end;
function  Num2Str(num:real;nk:byte):string;	begin Num2Str:=Num2Str(num,0,nk); end;
function  Num2Bool(num:int64):boolean; begin Num2Bool:=(num>=0); end;   
function  TimeSpec2Str(pts:Ptimespec):string;	begin TimeSpec2Str:=Num2Str(pts^.tv_sec,0)+'.'+Num2Str(round((pts^.tv_nsec/1000000000)),0) end;
function  TimeSpec2Num(pts:Ptimespec):real;		begin TimeSpec2Num:=		pts^.tv_sec + (					  pts^.tv_nsec/1000000000); end;
function  Str2Num(s:string; var num:byte):boolean;     var code:integer; begin val(StringReplace(s,'$','0x',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;
function  Str2Num(s:string; var num:smallint):boolean; var code:integer; begin val(StringReplace(s,'$','0x',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;
function  Str2Num(s:string; var num:int64):boolean;    var code:integer; begin val(StringReplace(s,'$','0x',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;
function  Str2Num(s:string; var num:qword):boolean;    var code:integer; begin val(StringReplace(s,'$','0x',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;
function  Str2Num(s:string; var num:longint):boolean;  var code:integer; begin val(StringReplace(s,'$','0x',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;
function  Str2Num(s:string; var num:longword):boolean; var code:integer; begin val(StringReplace(s,'$','0x',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;
function  Str2Num(s:string; var num:real):boolean;     
var code:integer; i64:int64; sh:string;
begin 
  sh:=StringReplace(s,'$','0x',[rfReplaceAll,rfIgnoreCase]);
  val(sh,num,code);
  if (code<>0) and Str2Num(sh,i64) then begin num:=i64; code:=0; end; 
  Str2Num:=(code=0); 
end;
function  Str2Num(s:string; var num:extended):boolean; 
var code:integer; r:real;
begin
  val(s,num,code); 
  if (code<>0) and Str2Num(s,r) then begin num:=r; code:=0; end;
  Str2Num:=(code=0); 
end;

function  Str2CP437(s:string):string;
var sh:string;
begin
  sh:=StringReplace(s ,'Ä',#$8e,[rfReplaceAll]); 
  sh:=StringReplace(sh,'Ö',#$99,[rfReplaceAll]); 
  sh:=StringReplace(sh,'Ü',#$9a,[rfReplaceAll]); 
  sh:=StringReplace(sh,'ä',#$84,[rfReplaceAll]); 
  sh:=StringReplace(sh,'ö',#$94,[rfReplaceAll]); 
  sh:=StringReplace(sh,'ü',#$81,[rfReplaceAll]); 
  sh:=StringReplace(sh,'ß',#$e1,[rfReplaceAll]); 
  sh:=StringReplace(sh,'§',#$15,[rfReplaceAll]);  
  Str2CP437:=sh;
end;

function  Str2TimeSpec(s:string; var ts:timespec):boolean;
var c1,c2:integer; 
begin 
  val(Select_Item(s,'.','',1),ts.tv_sec, c1); 
  val(Select_Item(s,'.','',2),ts.tv_nsec,c2); 
LOG_Writeln(LOG_ERROR,'Str2TimeSpec: '+s);
  Str2TimeSpec:=((c1=0) and (c2=0));
end;
function  Hex   (nr:qword;lgt:byte) : string; begin Hex:=Format('%0:-*.*x',[lgt,lgt,nr]); end;
{$warnings off} function  Hex   (ptr:pointer;lgt:byte): string; begin Hex:=Hex(qword(ptr),lgt); end; {$warnings on}
function  HexStr(s:string):string;overload; var sh:string; i:longint; begin sh:=''; for i := 1 to Length(s) do sh:=sh+Hex(ord(s[i]),2); HexStr:=sh; end;
function  LeadingZero(w:word):string; begin LeadingZero:=Format('%0:-*.*d',[2,2,w]); end;
//function  Get_FixedStringLen(s:string;cnt:word;leading:boolean):string; var fmt:string; begin fmt:='%0:'; if not leading then fmt:=fmt+'-'; fmt:=fmt+'*.*s'; Get_FixedStringLen:=Format(fmt,[cnt,cnt,s]); end;
function  Get_FixedStringLen(s:string;cnt:word;leading:boolean):string; var fmt:string; begin if leading then fmt:='%' else fmt:='%-'; fmt:=fmt+Num2Str(cnt,0)+'s'; Get_FixedStringLen:=Format(fmt,[s]); end;
//function  Upper(const s : string) : String; var sh : String; i:word; begin sh:=''; for i:= 1 to Length(s) do sh:=sh+Upcase(s[i]);   Upper:=sh; end;
//function  Lower(const s : string) : String; var sh : String; i:word; begin sh:=''; for i:= 1 to Length(s) do sh:=sh+LowerCase(s[i]);Lower:=sh; end;
function  Upper(const s:string):string; begin Upper:=UpCase(s); end;
function  Lower(const s:string):string; begin Lower:=LowerCase(s); end;
function  CharPrintable(c:char):string; begin if ord(c)<$20 then CharPrintable:=#$5e+char(ord(c) xor $40) else CharPrintable:=c; end;
function  StringPrintable(s:string):string; var sh : string; i : longint; begin sh:=''; for i:=1 to Length(s) do sh:=sh+CharPrintable(s[i]); StringPrintable:=sh; end;
procedure ShowStringList(StrList:TStringList); var n:longint; begin for n:= 1 to StrList.Count do writeln(StrList[n-1]); end;
function  AdjZahlDE(r:real;lgt,nk:byte):string; var s:string; begin s:=StringReplace(Num2Str(r,lgt,nk),'.',',',[]); AdjZahlDE:=s; end;
function  AdjZahl(s:string):string;
var hs:string; n,pkt,com:integer; DEformat:boolean; r:real;
begin  
  DEformat:=false; pkt:=POS('.',s); com:=POS(',',s); hs:='';
  if (pkt<com) and (com<>0) then DEformat:=true;
//writeln(DEformat,' ',pkt,' ',com);
  for n:=1 to Length(s) do
  begin
    case s[n] of
      '.': if (DEformat) then hs:=hs+''  else hs:=hs+'.';
      ',': if (DEformat) then hs:=hs+'.' else hs:=hs+'';
      else hs:=hs+s[n];
    end;
  end; // only . as decimalpoint
  hs:=StringReplace(hs,'.--','.00',[]); hs:=StringReplace(hs,'.-', '.00',[]); 
  if not Str2Num(hs,r) then hs:='';
  AdjZahl:=hs;
end;

procedure IPInfo_Init(intface:string; var IPInfo:IP_Info_t);
begin
  with IPInfo do
  begin  
    iface:=intface;	
	ip4addr:=noip_c;	ip6addr:=noip_c;	gwaddr:=noip_c;	nsaddr:=noip_c;	
  	domain:='';			hwaddr:='';			link:='';	
  	ssid:='';			signal:='';			DNSname:='';
  	stat:=false;		wireless:=false;
  end; // with
end;

procedure IPInfoShow(lvl:T_ErrorLevel; var IPInfo:IP_Info_t);
begin
  with IPInfo do
  begin
    SAY(lvl,alias+' Link:    '+link);
    SAY(lvl,'iface:        '+iface);
    SAY(lvl,'wireless:     '+Bool2Str(wireless));
    SAY(lvl,'stat:         '+Bool2Str(stat));
	SAY(lvl,'inet:         '+ip4addr);
//	SAY(lvl,'inetextern:   '+ip4ext);
	SAY(lvl,'inet6:        '+ip6addr);
	SAY(lvl,'ether:        '+hwaddr);
	SAY(lvl,'default via:  '+gwaddr);
	SAY(lvl,'nameserver:   '+nsaddr);
	SAY(lvl,'domain:       '+domain);
	SAY(lvl,'DNSname:      '+DNSname);
	if wireless then
	begin
	  SAY(lvl,'SSID:         '+ssid);
	  SAY(lvl,'Signal:       '+signal);
	end;
  end;
end;

function  GetHostNameOS:string;
var computer:string; {$IFDEF Win32}c:array[0..127] of Char; sz:dword;{$ENDIF}
begin
  computer:='';
  {$IFDEF Win32} sz:=SizeOf(c); GetComputerName(c,sz); computer:=c;
  {$ELSE} computer:=unix.GetHostName; {$ENDIF}
  GetHostNameOS:=computer;
end;

procedure IPInfo_GetOS(var IPInfo:IP_Info_t);
// idee: echo inet `ip a show wlan0 | grep -Po 'inet \K[\d.]+'`
// ip -f inet addr show wlan0 | grep -Po 'inet \K[\d.]+'
// IN: eth0 or wlan0
// eth: enx???????? wlan: wlx????????
  procedure xx(srch,istr:string; nr:longint; var ostr:string);
  begin 
    if 	(Pos(srch,istr)>0) and ((ostr='') or (ostr=noip_c)) then 
	  ostr:=Trimme(Select_Item(istr,' ','',nr),3);
  end;
var res:integer; n:longint; _tl:TStringList; sh:string;
begin
  _tl:=TStringList.create;   // echo wlan0 Link: `cat /sys/class/net/wlan0/carrier`
  with IPInfo do
  begin
    IPInfo_Init(iface,IPInfo);
    sh:=sudo+'ip a show '+iface+' ; '+
  		 	 'echo '+iface+' Link: `cat /sys/class/net/'+iface+'/carrier` ; ';
  	wireless:=((Pos('wlan',lower(iface))>0) or (Pos('wlx',lower(iface))>0));
  	if wireless then
  	begin
	sh:=sh+	'echo SSID: `iwgetid -r` ; '+
			'echo Signal: `cat /proc/net/wireless | tail -1 | awk ''{print $3}''` ; ';
//  	 wlan0: 0000   60.  -50.  -256        0      0      0     32      0        0
  	end;
  	sh:=sh+	'ip route show ; '+
  			'cat /etc/resolv.conf';
  	res:=call_external_prog(LOG_NONE,sh,_tl); 
//	SAY_TL(LOG_WARNING,_tl);	
  	if (res=0) then
  	begin
      for n:= 1 to _tl.count do
      begin
	  	sh:=Trimme(_tl[n-1],4);	// remove all unnecessary spaces
//		writeln(sh);
		xx('inet ',			sh,2,ip4addr);
		xx('inet6 ',		sh,2,ip6addr);
		xx('ether ',		sh,2,hwaddr);
		xx('default via ',	sh,3,gwaddr);
		xx('nameserver ',	sh,2,nsaddr);
		xx('domain ',		sh,2,domain);
		xx(iface+' Link:',	sh,3,link);
		xx('SSID: ',		sh,2,ssid);
      	if wireless and (Pos('Signal: ',sh)>0) then 
      	begin
    	  signal:=		Trimme(Select_Item(sh,' ','',2),3);
//		  writeln('sig:',signal,':',sh);
    	  if (signal='') or (signal='tus')
    	  	then signal:=	none_c
    		else signal:=	StringReplace(signal,'.','%',[]);
      	end;
      end; // for
  	end else LOG_Writeln(LOG_ERROR,'GetIPInfos: '+Num2Str(res,0));
  	if (link='1') then link:='UP' else link:='DOWN';
  	_tl.free;
  	stat:=((link='UP') and (ip4addr<>noip_c));
  	if stat then DNSname:=LNX_ResolveIP2name(Select_Item(ip4addr,'/','',1));
//GetIPInfos[wlan0]: MAC:b8:27:eb:d9:a6:01 IP4:10.8.81.135/24 IP6:noIPAdr GW:10.8.81.1 DNS:10.8.81.1 Domain:muo.basis.biz ext:188.192.178.135
  	sh:='GetIPInfos['+alias+'/'+iface+']: MAC:'+hwaddr+' IP4:'+ip4addr+' IP6:'+ip6addr+' GW:'+gwaddr+' DNS:'+nsaddr+' Domain:'+domain+' dnsname:'+DNSname+' wireless:'+Bool2Str(wireless);
//	if stat then SAY(LOG_INFO,sh) else SAY(LOG_WARNING,sh);
//	IPInfoShow(LOG_INFO,IPInfo);
  end; // with
end;

procedure  IPInfo_GetOS(var IPInfos:IP_Infos_t);
var ok:boolean; n,i1,i2,anz,_idx:longint; devnam:string;
begin
  ok:=false;
  with IPInfos do
  begin
    if not init then 	// access HW
    begin
      hostname:=GetHostNameOS;
      if (call_external_prog(LOG_NONE,'ls -1r /sys/class/net/',devlst)<>0) then devlst:='';
      if (call_external_prog(LOG_NONE,'dig +short myip.opendns.com @resolver1.opendns.com',ip4ext)<>0) then ip4ext:=noip_c;	
	  devlst:=StringReplace(devlst,LineEnding,',',[rfReplaceAll]);	// wlan0,lo,eth0,ap0
// writeln('devlist:',devlst,':');
      samesubnet:=false;
      anz:=Anz_Item(devlst,',','');
	  for n:= 1 to anz do 
	  begin
	    devnam:=Trimme(Select_Item(devlst,',','',n),3);	// e.g. wlan0 or wlx?????
	    _idx:=-1;
	    if (Pos('wlan0',devnam)>0) or (Pos('wlx',devnam)>0)	then _idx:=0;
	    if (Pos('wlan1',devnam)>0) 							then _idx:=3;
	    if (Pos('eth',  devnam)>0) or (Pos('enx',devnam)>0)	then _idx:=1;
	    if (devnam=ifuap_c)									then _idx:=2; // IP_infomax_c
	    if (_idx>=0) and (_idx<=IP_infomax_c) then
	    begin
	      IP_Info[_idx].iface:=devnam;
		  IPInfo_GetOS(IP_Info[_idx]);
//		  if (IP_Info[_idx].iface=ifuap_c) then IP_Info[_idx].ssid:='';		  
		  if not ok then 
		  begin
		  	if IP_Info[_idx].stat then 
		  	begin
			  ok:=true;
			  idx:=n;
		  	end;
		  end;
// IPInfoShow(LOG_INFO,IP_Info[_idx]);
		end; // else LOG_Writeln(LOG_ERROR,'IPInfo_GetOS: wrong idx '+Num2Str(_idx,0));
	  end; // for
	  init:=true;
	end; // if
	
(*	for n:= 1 to 2 do
	begin
	  if not samesubnet then 
		samesubnet:=
		  ((IP_Info[n-1].ip4addr<>noip_c) and (IP_Info[n].ip4addr<>noip_c) and 
		  	IP4AddrsInSameSubnet(IP_Info[n-1].ip4addr,IP_Info[n].ip4addr));
	end; *)

	i1:=IPInfo_GetIdx(ifeth_c); i2:=IPInfo_GetIdx(ifwlan_c);
	samesubnet:=
	  ((IP_Info[i1].ip4addr<>noip_c) and (IP_Info[i2].ip4addr<>noip_c) and 
		IP4AddrsInSameSubnet(IP_Info[i1].ip4addr,IP_Info[i2].ip4addr));

//writeln('idx:',idx,' samesubnet:',samesubnet);
  end; // with
end;

function  IPInfo_GetIdx(intface:string):longint;
var n,_idx:longint;
begin
  _idx:=0;
  for n:= 0 to IP_infomax_c do
  begin
    with IP_Infos.IP_Info[n] do
  	begin
  	  if (iface=intface) or (alias=intface) then _idx:=n;
  	end; // with
  end;
  IPInfo_GetIdx:=_idx;
end;

function  IP_iface(aliasname:string):string;
// IN: wlan0 OUT: wlan0 or wlxxxxxxx
begin
  IPInfo_GetOS(IP_Infos);
  IP_iface:=IP_Infos.IP_Info[IPInfo_GetIdx(aliasname)].iface;
end;
function  IP4_Addr(iface:string):string;
begin
  IPInfo_GetOS(IP_Infos);
  IP4_Addr:=IP_Infos.IP_Info[IPInfo_GetIdx(iface)].ip4addr;
end;
function  IP6_Addr(iface:string):string;
begin
  IPInfo_GetOS(IP_Infos);
  IP6_Addr:=IP_Infos.IP_Info[IPInfo_GetIdx(iface)].ip6addr;
end;

function  GetDomainName(iface:string):string;
begin
  IPInfo_GetOS(IP_Infos);
  GetDomainName:=IP_Infos.IP_Info[IPInfo_GetIdx(iface)].domain;
end;

function  GetDomainName:string;
var sh:string;
begin
  IPInfo_GetOS(IP_Infos);
  with IP_Infos do
  begin
    if (idx>=0) and (idx<=IP_infomax_c) then sh:=IP_Infos.IP_Info[idx].domain else sh:='';
  end; // with
  GetDomainName:=sh;
end;

function  GetMainDomainName:string;
var n:longint; domain:string;
begin
  domain:=GetDomainName;	// def.ghi.com
  n:=Anz_Item(domain,'.','');
  if (n>=2) then domain:=Select_RightItems(domain,'.','',(n-1)); // ghi.com
  GetMainDomainName:=domain;
end;

function  GetHostName:string; 
begin 
  IPInfo_GetOS(IP_Infos);
  GetHostName:=IP_Infos.hostname;
end;

function  GetWLANSignal(iface:string):longint; 	// -1,0-100
// -1: not avail // 0-100%
var _idx,_sig:longint;
begin
  _sig:=-1;
  _idx:=IPInfo_GetIdx(iface);
  with IP_Infos.IP_Info[_idx] do
  begin
	if wireless then 
	  if not Str2Num(GetNumChar(signal),_sig) then _sig:=-1;
  end; // with
(*SAY(LOG_WARNING,'GetWLANSignal: '+iface+' '+Num2Str(_idx,0)+' '+Num2Str(_sig,0));
IPInfoShow(LOG_WARNING,IP_Infos.IP_Info[_idx]); *)
  GetWLANSignal:=_sig;
end;

function  RPI_WLANavailChan(cntry:string):string;
const _2Ghz='1|2|3|4|5|6|7|8|9|10|11|12|13|';
	  _5Ghz='36|40|44|48|52|56|60|64|100|104|108|112|116|120|124|128|132|136|140|';
var sh:string;
begin
  sh:='';
  case RPI_bType of
  	8,$0a,$0c:	sh:=_2GHz;
	$0d:		sh:=_2GHz+_5GHz;
  end; // case
  RPI_WLANavailChan:=CSV_RemLastSep(sh,'|');
end;

function MAC_Addr(iface:string; fmt:byte):string;
var n:longint; sh:string;
begin 
  IPInfo_GetOS(IP_Infos);
  sh:=GetHexChar(IP_Infos.IP_Info[IPInfo_GetIdx(iface)].hwaddr);
  if (Length(sh)<12) then sh:=cpu_snr;
  case fmt of
    1..12: 	begin
      		  n:=Length(sh); 
      		  if (n>=fmt) then sh:=copy(sh,n-fmt+1,fmt) else sh:='';
      		end;
  end; // case
  MAC_Addr:=sh;  
end;

function  IP4_AddrExt:string;
begin
  IPInfo_GetOS(IP_Infos);
  IP4_AddrExt:=IP_Infos.ip4ext;
end;

function  IP4_AddrValid(ipstr:string):boolean;
// e.g. 192.168.1.2/32
const cnt_c=4;
var ok:boolean; n,anz,li:longint; sh,sh1,sh2:string; 
begin
  ok:=false;
  sh1:=Select_Item(ipstr,'/','',1); 	// 192.168.1.2
  sh2:=Select_Item(ipstr,'/','',2); 	// 24
  sh:=FilterChar(sh1,'0123456789.');	// filter all valid 
  if (sh=sh1) then
  begin
	anz:=Anz_Item(sh,'.','');
	if (anz=cnt_c) then
	begin
	  ok:=true;
	  for n:= 1 to cnt_c do
	  begin
	    if Str2Num(Select_Item(sh,'.','',n),li) then 
	    begin
	      if ((li<0) or (li>$ff)) then ok:=false;
	    end else ok:=false;
	  end;
	end;
	if (ok and (sh2<>'')) then
	begin // chk netmask
	  if Str2Num(sh2,li) then
	  begin
	    if (li<8) or (li>32) then ok:=false;
	  end else ok:=false;
	end;
  end;
  IP4_AddrValid:=ok;
end;

function  IP4AddrListValid(ipliststr:string):boolean;
// e.g. 192.168.1.0/24,10.8.12.34,10.8.12.56
// check for IPTables
var ok:boolean; n:longint; sh:string;
begin
  ok:=true;
  for n:=1 to Anz_Item(ipliststr,',','') do
  begin
    sh:=Select_Item(ipliststr,',','',n);
	if not IP4_AddrValid(sh) then 
	begin
	  ok:=false;
	  LOG_Writeln(LOG_ERROR,'IP4AddrListValid: '+sh+' no valid entry in list '+ipliststr);
	end;
  end;
  IP4AddrListValid:=ok;
end;

function  IP6_AddrValid(ipstr:string):boolean;
// e.g. 2001:0db8:85a3:08d3:1319:8a2e:0370:7344/48
const cnt_c=8;
var ok:boolean; n,anz,li:longint; sh,sh1,sh2:string; 
begin
  ok:=false;
  sh1:=Select_Item(ipstr,'/','',1); 	// 2001:0db8:85a3:08d3:1319:8a2e:0370:7344
  sh2:=Select_Item(ipstr,'/','',2); 	// 48
  sh:=FilterChar(sh1,'0123456789abcdefABCDEF:');	// filter all valid 
  if (sh=sh1) then
  begin
	anz:=Anz_Item(sh,'.','');
	if (anz=cnt_c) then
	begin
	  ok:=true;
	  for n:= 1 to cnt_c do
	  begin
	    if Str2Num(Select_Item(sh,':','',n),li) then 
	    begin
	      if ((li<0) or (li>$ffff)) then ok:=false;
	    end else begin if (sh<>'') then ok:=false; end;
	  end;
	end;
	if (ok and (sh2<>'')) then
	begin // chk netmask
	  if Str2Num(sh2,li) then
	  begin
	    if (li<16) or (li>128) then ok:=false;
	  end else ok:=false;
	end;
  end;
  IP6_AddrValid:=ok;
end;

function  IP6AddrListValid(ipliststr:string):boolean;
// e.g. 2001:0db8:85a3:08d3:1319:8a2e:0370:7344/48,2001:0db8:85a3:08d3:1319:8a2e:0370:7345
var ok:boolean; n:longint; sh:string;
begin
  ok:=true;
  for n:=1 to Anz_Item(ipliststr,',','') do
  begin
    sh:=Select_Item(ipliststr,',','',n);
	if not IP6_AddrValid(sh) then 
	begin
	  ok:=false;
	  LOG_Writeln(LOG_ERROR,'IP6AddrListValid: '+sh+' no valid entry in list '+ipliststr);
	end;
  end;
  IP6AddrListValid:=ok;
end;

function  IPAddrListValid(ipliststr:string):boolean;
// e.g. 2001:0db8:85a3:08d3:1319:8a2e:0370:7344/48,2001:0db8:85a3:08d3:1319:8a2e:0370:7345
var ok:boolean; n:longint; sh:string;
begin
  ok:=true;
  for n:=1 to Anz_Item(ipliststr,',','') do
  begin
    sh:=Select_Item(ipliststr,',','',n);
	if not (IP4_AddrValid(sh) or IP6_AddrValid(sh)) then 
	begin
	  ok:=false;
	  LOG_Writeln(LOG_ERROR,'IPAddrListValid: '+sh+' no valid entry in list '+ipliststr);
	end;
  end;
writeln('IPAddrListValid:',ipliststr,':',ok);
  IPAddrListValid:=ok;
end;

function  IP4AddrsInSameSubnet(ip4adr1,ip4adr2:string):boolean;
// ip4adr1:	192.168.1.172
// ip4adr2:	192.168.1.0/24
// valid:	/8 /16 /24 /32
var _ok:boolean; subm:longint; ipn1,ipn2:string;
begin
  _ok:=false;
  if IP4_AddrValid(ip4adr1) and IP4_AddrValid(ip4adr2) then
  begin
    if not 	 Str2Num(Select_Item(ip4adr2,'/','',2),subm) then 
	  if not Str2Num(Select_Item(ip4adr1,'/','',2),subm) then subm:=24;

    subm:=round(subm/8);
    
	ipn2:=Select_Item(ip4adr2,'/','',1); 		// 192.168.1.0
	ipn2:=Select_LeftItems(ipn2,'.','',subm); 	// 192.168.1
	
    ipn1:= Select_Item(ip4adr1,'/','',1); 		// 192.168.1.172
    ipn1:= Select_LeftItems(ipn1,'.','',subm); 	// 192.168.1
    
    _ok:=(ipn1=ipn2);
  end;
  IP4AddrsInSameSubnet:=_ok;
end;

function  ShortString(fmt,maxlgt,divdr:longint; str:string):string;
const shrtA='..'; shrtE='\u2026'; // horizontalEllipsis
var li1,li2:longint; sh:string;
begin
  if (Length(str)>maxlgt) then
  begin
    if (divdr<2) then fmt:=1; // avoid div 0
    case fmt of
        0:	sh:=str;	// no shorting  
        3:	begin		// break string in 2 parts, break defined by 'divdr' e.g. 3
       		  li1:=((maxlgt-Length(shrtA)) div divdr)*(divdr-1); li2:=maxlgt-li1-Length(shrtA);
       		  sh:=copy(str,1,li1)+shrtA+copy(str,(Length(str)+1-li2),li2);
//writeln('origstr:',str); writeln('shorted:',sh);
       		 end;
        2:	sh:=shrtA+copy(str,Length(str)-maxlgt+1+Length(shrtA),maxlgt);	// cut left
	    4:	sh:=copy(str,1,(maxlgt-Length(shrtA)))+shrtA;					// cut right

       30:	begin // Ellipsis: break string in 2 parts, break defined by 'divdr' e.g. 3
       		  li1:=((maxlgt-1) div divdr)*(divdr-1); li2:=maxlgt-li1-1;
       		  sh:=copy(str,1,li1)+shrtE+copy(str,(Length(str)+1-li2),li2);
//writeln('origstr:',str); writeln('shorted:',sh);      
      		end;
       20:	sh:=shrtE+copy(str,Length(str)-maxlgt+1+1,maxlgt);				// cut left
       40:	sh:=copy(str,1,(maxlgt-1))+shrtE;								// cut right
      else	sh:=ShortString(40,maxlgt,divdr,str);
    end;
  end else sh:=str;
  ShortString:=sh;
end;

function  Num2Limit(var Value:real; MinOut,MaxOut:real):boolean;
var valold:real;
begin 
  valold:=Value;
  if Value<MinOut then Value:=MinOut 
  				  else if Value>MaxOut then Value:=MaxOut; 
  Num2Limit:=(Value<>valold);
end;

function  FormatFileSize(const Size: Int64):string;
var fSize:real; sh,Fmt,Units:string;
begin
  Fmt:='%.1f%s';
  if (Size>(1 shl 20)) then begin // Mb
    if (Size>(1 shl 30)) then begin // Gb
      if (Size>(1 shl 40)) then begin // Tb
        fSize:=Size*(1/(1 shl 40));
        Units:='Tb';
      end else
      //if (Size>(1 shl 30)) then // Gb
      begin
        fSize:=Size*(1/(1 shl 30));
        Units:='Gb';
      end;
    end else
    //if (Size>(1 shl 20)) then // Mb
    begin
      fSize:=Size*(1/(1 shl 20));
      Units:='Mb';
    end;
  end else
  if (Size>(1 shl 10)) then begin //kb
    fSize:=Size*(1/(1 shl 10));
    Units:='kb';
  end else begin
    fSize:=Size;
    Units:='b';
    Fmt:='%.0f%s';
  end;
  FmtStr(sh,Fmt,[fSize,Units]);
  FormatFileSize:=sh;
end;

procedure AskCR(lvl:T_ErrorLevel; msg:string); begin writeln; write(msg+'<CR>'); readln; end;
procedure AskCR(msg:string); begin AskCR(LOG_INFO,msg); end;
procedure AskCR; begin AskCR(''); end;
function  AskStr(msg:string; var outstr:string):boolean;
begin
  write('enter '+msg+' (<string> or <CR> for exit): '); readln(outstr);
  AskStr:=(outstr<>'');
end;
function  AskYN(msg:string; dflt:string):boolean;
const yn_c='y/n';
var outchar,sh:string;
begin
  sh:=yn_c; dflt:=Upper(dflt);
  if dflt='N' then sh:='y/N'; if dflt='Y' then sh:='Y/n';
  repeat
    write('enter '+msg+' ('+sh+'): '); readln(outchar); outchar:=Upper(outchar);
    if (outchar='') and (sh<>yn_c) then outchar:=dflt;
  until ((outchar='Y') or (outchar='N'));
  AskYN:=(outchar='Y');
end;

function  AskNum(von,bis:longint; msg:string; var outnum:longint):boolean;
var _ok:boolean; sh:string;
begin
  repeat
    write('enter '+msg+' (',von:0,'-',bis:0,' or -1 for exit): '); readln(sh);
    _ok:=Str2Num(sh,outnum);
    _ok:=( _ok and (((outnum>=von) and (outnum<=bis)) or (outnum=-1)));
  until _ok;
  AskNum:=(outnum<>-1);
end;

function  StrHex(Hex_strng:string):string;
const tab:array[1..6] of byte=($0a,$0b,$0c,$0d,$0e,$0f);
var s,sh:string; i:longint; b,bh:byte; pending:boolean;
begin
  sh:=''; bh:=$00; s:=GetHexChar(Hex_strng); pending:=((Length(s) mod 2)<>0);
  for i := 1 to Length(s) do
  begin
    b:=ord(s[i]);
	if (b>=$30) and (b<=$39) then b:=b and $0f else b:=tab[(b and $0f)];
	if (((i-1) mod 2) <> 0) or ((i=Length(s)) and pending) then 
	begin 
	  bh:=bh or b; sh:=sh+char(bh); bh:=$00; 
	end 
	else bh:=b shl 4;
  end;
  StrHex:=sh;
end;

function  Str2DateTime(tdstring,fmt:string; var dt:TDateTime):boolean;
var _ok:boolean;
begin 
  try
	_ok:=true;
	dt:=ScanDateTime(fmt,tdstring);
  except
	_ok:=false;
  end;
  Str2DateTime:=_ok; 
end; 

function  scale(valin,min1,max1,min2,max2:real):real;
var r1,r2:real;
begin
  r2:=valin;
  if (valin>=min1) and (valin<=max1) then
  begin
    r1:=max1-min1;
    if r1<>0 then
    begin
      r2:=valin*(max2-min2)/r1;
    end else LOG_Writeln(LOG_ERROR,'Scale: wrong min1/max1 value pair');
  end else LOG_Writeln(LOG_ERROR,'Scale: valin not in range of min1/max1 value pair');
  scale:=r2;
end;

function  LeadingZeros(l:longint;digits:byte):string;
var s1,s2:string; i:byte; 
begin
  s1:=''; for i := 1 to digits do s1:=s1+'0'; Str(l:0,s2); s1:=s1+s2; 
  LeadingZeros:=copy(s1,Length(s1)-digits+1,255); 
end;

function  IsDir(filname:string):boolean;
begin IsDir:=((FileGetAttr(PrepFilePath(filname)) and faDirectory)<>0); end;

function  SetFileAge(filname:string; mode:integer; fdat:TDateTime):integer;
// mode: 1:modification date / 2:access date / 0: both dates
var res:integer; fn,cmd,sh:string;
begin
  res:=0; fn:=PrepFilePath(filname);
  if FileExists(fn) then 
  begin
	cmd:='touch';
	case mode of
	  1: cmd:=cmd+' -m';
	  2: cmd:=cmd+' -a';
	end; // case
	cmd:=cmd+' -t '+FormatDateTime('YYYYMMDDhhmm',fdat)+' '+fn;
	if not (call_external_prog(LOG_NONE,cmd,sh)=0) then res:=-1;
  end else res:=-1;
  if res<0 then Log_Writeln(Log_ERROR,'SetFileAge: '+cmd);
  SetFileAge:=res;
end;

function  GetFileAge(filname:string):TDateTime;
var fa:longint; fildat:TDateTime; fn:string;
begin
  fildat:=0; fn:=PrepFilePath(filname);
  if FileExists(fn) then 
  begin
    {$I-} fa:=FileAge(fn); if fa<>-1 then fildat:=FileDateToDateTime(fa); {$I+}
  end;
  GetFileAge:=fildat;
end;

function  GetFileSize(filname:string):int64;
var filsiz:int64; f:file; fn:string;
begin
  filsiz:=-1; fn:=PrepFilePath(filname);
  if FileExists(fn) then 
  begin
    {$I-} 
      assign(f,fn); 
      reset (f,1);
	  filsiz:=FileSize(f); 
	  close(f); 
	{$I+}
  end;
  GetFileSize:=filsiz;
end;

function  GetFilePackSize(filelist:string):int64;
var n:longint; res,sum:int64;
begin
  sum:=0;
  for n:=1 to Anz_Item(filelist,',','"') do
  begin
    res:=GetFileSize(Select_Item(filelist,',','"',n));
    if (res>0) then sum:=sum+res;
  end;
  GetFilePackSize:=sum;
end;

function  GetFileAgeInSec(filname:string):int64;
var fa:longint; res:int64; fildat:TDateTime; fn:string;
begin
  fildat:=0; res:=-1; fn:=PrepFilePath(filname);
  if FileExists(fn) then 
  begin
    {$I-} 
	  fa:=FileAge(fn); 
	  if fa<>-1 then 
	  begin 
	    fildat:=FileDateToDateTime(fa); 
		res:=round(SecondsBetween(now,fildat)); 
	  end; 
	{$I+}
  end;
  GetFileAgeInSec:=res;
end;

function  GetRNDsec(seconds_old,varianz:longint):longint;
var v,vh:longint;
begin
  v:=seconds_old;
  if varianz<>0 then
  begin
    vh:=varianz div 2; v:=Random(varianz+1); v:=vh-v; v:=seconds_old-v; if v<0 then v:=seconds_old;
  end;
  GetRNDsec:=v;
end;

function  FileIsRecent(filepath:string; seconds_old,varianz:longint):boolean;
var ok:boolean; tdat:TDateTime;
begin
  ok:=false;
  if FileExists(filepath) then 
  begin
	tdat:=GetFileAge(filepath); 
	ok:=(SecondsBetween(now,tdat)<=GetRNDsec(seconds_old,varianz));
//	LOG_Writeln(LOG_Warning,Bool2Str(ok)+' Delta: '+Num2Str(DeltaTime_in_min(now,tdat),0)+' min FileDate: '+GetXMLTimeStamp(tdat)+' '+Real2Str(v/60,0,2)+' min');
  end;
  FileIsRecent:=ok;
end;

function  FileIsRecent(filepath:string; seconds_old:longint):boolean;
begin
  FileIsRecent:=FileIsRecent(filepath,seconds_old,0);
end;

function adjL(s:string):string;
{.c schmeisst leading Blanks weg. }
var i,j : word; sh : string; first : boolean;
begin
  first := true; j := 1;
  sh := s;
  for i := 1 to Length(sh) do
    if (sh[i] = ' ') and (first) then j := i else first := false;
  if (j>0) and (j<=Length(sh)) then if sh[j] = ' ' then INC(j);
  sh := copy(sh,j,Length(sh)-j+1);
  adjL := sh;
end;

function adjT(s:string):string;
{.c schmeisst trailing Blanks weg. }
var i,j : integer; sh : string; first : boolean;
begin
  sh := s; first := true; j := length(sh);
  for i := Length(sh) downto 1 do
    if (sh[i]  = ' ') and (first) then j := i else first := false;
  if (j>0) and (j<=Length(sh)) then if sh[j] = ' ' then DEC(j);
  sh := copy(sh,1,j);
  adjT := sh;
end;

function adjM(s:string):string;
{.c schmeisst mehrfach folgende Blanks weg. }
var sh,sh2:string;
begin
  sh:=s; 
  repeat sh2:=sh; delete(sh,Pos('  ',sh),1); until sh=sh2;
  adjM:=sh;
end;

function adj(s:string):string; begin adj := adjL(adjT(s)); end;  
function adjAll(s:string):string; begin adjALL := adjM(adj(s));  end;

function  Trimme(s:string;modus:byte):string;
var sh:string; { modus: 1:adjL 2:adjT 3:AdjLT 4:AdjLMT 5:AdjLMTandRemoveTABs }
begin
  sh := s;
  case modus of
    0  : ;
    1  : sh := adjL(s);
	2  : sh := adjT(s);
	3  : sh := adj(s);
	4  : sh := adjAll(s);
	5  : sh := adjAll(StringReplace(s,#$09,' ',[rfReplaceAll]));
	$0a: sh := adjAll(StringReplace(s,#$0a,' ',[rfReplaceAll]));
	else sh := adjAll(s);
  end;
  Trimme := sh;  
end;

function FilterChar(s,filter:string):string;
{.c filtert aus string s alle char die in filter angegeben sind. }
var sh:string; i,j:integer;
begin
  sh:=s; 
  if Length(filter) > 0 then
  begin
    sh:='';
	for i := 1 to Length(s) do
	begin
      for j := 1 to Length(filter) do
      begin
	    if s[i]=filter[j] then sh:=sh+s[i];
	  end;
	end;
  end;
  FilterChar:=sh;
end;

function RemoveChar(s,filter:string):string;
// remove all char from 's' which 'filter' contains 
var sh:string; i:integer;
begin
  sh:=s; 
  if Length(filter)>0 then
  begin
    sh:='';
	for i:=1 to Length(s) do
	  if (Pos(s[i],filter)=0) then sh:=sh+s[i];
  end;
  RemoveChar:=sh;
end;

function GetHexChar(s:string):string;
begin GetHexChar:=FilterChar(s,'0123456789ABCDEFabcdef'); end;

function GetNumChar(s:string):string;
begin GetNumChar:=FilterChar(s,'0123456789'); end;

function GetAlphaNumChar(s:string):string;
begin GetAlphaNumChar:=FilterChar(s,'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'); end;

function GetParserTokenChar(s:string):string;
begin GetParserTokenChar:=FilterChar(s,'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_'); end;

function ContainDescenderLetter(s:string):boolean; // string has char with descender (unterlaenge)
begin ContainDescenderLetter:=(FilterChar(s,'gjpqyß_,;')<>''); end;

function ReplaceChars(s,filterchars,replacechar:string):string;
{.c ersetzt aus string s alle char die in filter angegeben sind mit replacechar }
var sh:string; i:integer;
begin
  sh:=s; 
  for i := 1 to Length(filterchars) do sh:=StringReplace(sh,filterchars[i],replacechar,[rfReplaceAll]);
  ReplaceChars:=sh;
end;

function  RM_LF  (s:string):string; begin RM_LF:=  ReplaceChars(s,#$0a,''); end;
function  RM_CR  (s:string):string; begin RM_CR:=  ReplaceChars(s,#$0d,''); end;
function  RM_CRLF(s:string):string; begin RM_CRLF:=ReplaceChars(s,#$0d+#$0a,''); end;

function  SB_Null(s:string):string; begin SB_Null:=StringReplace(s,'\0',#$00,[rfReplaceAll]); end;
function  SB_Bell(s:string):string; begin SB_Bell:=StringReplace(s,'\a',#$07,[rfReplaceAll]); end;
function  SB_BS  (s:string):string; begin SB_BS:=  StringReplace(s,'\b',#$08,[rfReplaceAll]); end;
function  SB_TAB (s:string):string; begin SB_TAB:= StringReplace(s,'\t',#$09,[rfReplaceAll]); end;
function  SB_LF  (s:string):string; begin SB_LF:=  StringReplace(s,'\n',#$0a,[rfReplaceAll]); end;
function  SB_CR  (s:string):string; begin SB_CR:=  StringReplace(s,'\r',#$0d,[rfReplaceAll]); end;
function  SB_FF  (s:string):string; begin SB_FF:=  StringReplace(s,'\f',#$0c,[rfReplaceAll]); end;
function  SB_ESC (s:string):string; begin SB_ESC:= StringReplace(s,'\e',#$1b,[rfReplaceAll]); end;
function  SB_VT  (s:string):string; begin SB_VT:=  StringReplace(s,'\v',#$0b,[rfReplaceAll]); end;
function  SB_CRLF(s:string):string; begin SB_CRLF:=SB_LF(SB_CR(s)); end;
function SB_UnESC(s:string):string; begin SB_UnESC:= SB_CRLF(SB_FF(SB_TAB(SB_BS(SB_VT(SB_Bell(SB_Null(SB_ESC(s)))))))); end;  

function  BS_Null(s:string):string; begin BS_Null:=StringReplace(s,#$00,'\0',[rfReplaceAll]); end;
function  BS_Bell(s:string):string; begin BS_Bell:=StringReplace(s,#$07,'\a',[rfReplaceAll]); end;
function  BS_BS	 (s:string):string; begin BS_BS:=  StringReplace(s,#$08,'\b',[rfReplaceAll]); end;
function  BS_TAB (s:string):string; begin BS_TAB:= StringReplace(s,#$09,'\t',[rfReplaceAll]); end;
function  BS_LF  (s:string):string; begin BS_LF:=  StringReplace(s,#$0a,'\n',[rfReplaceAll]); end;
function  BS_CR  (s:string):string; begin BS_CR:=  StringReplace(s,#$0d,'\r',[rfReplaceAll]); end;
function  BS_FF  (s:string):string; begin BS_FF:=  StringReplace(s,#$0c,'\f',[rfReplaceAll]); end;
function  BS_ESC (s:string):string; begin BS_ESC:= StringReplace(s,#$1b,'\e',[rfReplaceAll]); end;
function  BS_VT  (s:string):string; begin BS_VT:=  StringReplace(s,#$0b,'\v',[rfReplaceAll]); end;
function  BS_CRLF(s:string):string; begin BS_CRLF:=BS_LF(BS_CR(s)); end;
function BS_DoESC(s:string):string; begin BS_DoESC:= BS_CRLF(BS_FF(BS_TAB(BS_BS(BS_VT(BS_Bell(BS_Null(BS_ESC(s)))))))); end; 

function  BS_HK  (s:string):string; begin BS_HK:=  StringReplace(s,#$27,'\''',[rfReplaceAll]); end;
function  BS_dHK (s:string):string; begin BS_dHK:= StringReplace(s,#$22,'\"',[rfReplaceAll]); end;
function  BS_QM  (s:string):string; begin BS_QM:=  StringReplace(s,#$3f,'\?',[rfReplaceAll]); end;
function  BS_Bsl (s:string):string; begin BS_Bsl:= StringReplace(s,#$5c,'\\',[rfReplaceAll]); end; 
function  BS_ALL (s:string):string; begin BS_ALL:= BS_HK(BS_dHK(BS_QM(BS_DoESC((s))))); end; 
//function  BS_ALL (s:string):string; begin BS_ALL:= BS_Bsl(BS_HK(BS_dHK(BS_QM(BS_DoESC((s)))))); end; 

function  CamelCase(strng:string):string; 
// IN:  CamelCase
// OUT: -camel-case
var i:longint; c:char; sh:string;
begin 
  sh:='';
  for i:= 1 to Length(strng) do
  begin
    c:=strng[i];
	if (Upper(c)=c) and (c<>' ') then sh:=sh+'-'; 
	if c<>' ' then sh:=sh+LowerCase(c);
  end;
  CamelCase:=sh; 
end;

function GetPrintableChars(s:string; c1,c2:char):string;
var sh:string; i:word;
begin
  sh:='';
  for i := 1 to Length(s) do
    if ((ord(s[i])>=ord(c1)) and (ord(s[i])<=ord(c2))) then sh:=sh+s[i]; { #$<c1>..#$<c2> }	   
  GetPrintableChars:=sh;
end;

function  HashTag(modus:byte; filname,comment1,comment2:string):string;
var hash,sh,fn:string; dt:TDateTime; m:TMemoryStream; f:file of byte; oldfilemode:byte; siz:int64;
begin
  hash:=''; fn:=PrepFilePath(filname);
  case modus of
      1 : begin // MD5 Hash constructed with FileDate;FileSize and a comment string
            dt:=GetFileAge(fn);
            if dt>0 then 
		    begin
              {$I-} assign(f,fn); 
			  oldfilemode:=filemode; filemode:=0; 	// readonly
//writeln('HashTag1');			
			  reset(f,1); 	// hier hängt darwin, wenn access privs auf datei nicht stimmen!!!	
//writeln('HashTag2');
			  filemode:=oldfilemode;			  
			  siz:=FileSize(f);		  
			  close(f); {$I+} 
			  sh:=FormatDateTime('yyyy-mm-dd',dt)+'T'+ // YEAR-MM-DDThh:mm:ss.zz
			      FormatDateTime('hh:nn:ss.zz',dt)+';'+
				  Num2Str(siz,0)+';'+Num2Str(modus,0)+';'+comment1+';'+comment2;
		      hash:=MD5Print(MD5String(sh)); 
		    end
		    else LOG_Writeln(LOG_Error,'HashTag: file does not exist: '+fn);
          end;		  
      2 : begin // MD5 Hash of filecontent
	        m:=TMemoryStream.create;
	        if not File2MStream(fn,m,hash) then 
		    begin hash:=''; LOG_Writeln(LOG_Error,'HashTag: file does not exist: '+fn); end;
		    m.free;
	      end;
	   3: begin // MD5 Hash auf String 'comment1'
	        hash:=MD5Print(MD5String(comment1)); 
	      end;
	 else LOG_Writeln(LOG_ERROR,'HashTag: wrong modus '+Num2Str(modus,0));
  end; // case
//writeln('HashTag:',hash,':',fn);
  HashTag:=hash;
end;

function  HashTag(var InString:string):string; begin HashTag:=HashTag(3,'',InString,''); end;

procedure FSplit(fullfilename:string; var Directory,FName,Extension:string; extwithdot:boolean);
var anz:integer; ext:string;
begin
  anz:=Anz_Item(fullfilename,dir_sep_c,''); ext:='';
  Directory:=Select_LeftItems (fullfilename,dir_sep_c,'',anz-1); 
  Fname:=    Select_RightItems(fullfilename,dir_sep_c,'',anz); 
  Extension:=Select_Item(Fname,ext_sep_c,'',Anz_Item(Fname,ext_sep_c,''));
  if (Extension<>'') then ext:=ext_sep_c+Extension;
  Fname:=StringReplace(Fname,ext,'',[rfReplaceAll,rfIgnoreCase]);
  if (Extension<>'') and (extwithdot) then Extension:=ext_sep_c+Extension;
//writeln(fullfilename,'|',directory,'|',fname,'|',extension,'-',dir_sep_c);
end;

function  Get_ExtName(fullfilename:string; extwithdot:boolean):string; 
var fext:string;
begin 
  fext:=ExtractFileExt(fullfilename);
  if not extwithdot then
    if Pos(ext_sep_c,fext)=1 then fext:=copy(fext,2,Length(fext));
  Get_ExtName:=fext; 
end;

function  Get_FName(fullfilename:string; withext:boolean):string; 
var Directory,FName,Extension,sh:string;
begin 
  FSplit(fullfilename,Directory,FName,Extension,true); 
  sh:=Fname; if withext then sh:=sh+Get_ExtName(fullfilename,true);
  Get_FName:=sh; 
end;
function  Get_FName(fullfilename:string):string; begin Get_FName:=Get_FName(fullfilename,false); end;

function  Get_FNameExt(fullfilename:string):string; 
var Directory,FName,Extension : string;
begin FSplit(fullfilename,Directory,FName,Extension,true); Get_FNameExt:=Fname+Extension; end;

function  Get_Dir(fullfilename:string):string; 
var Directory,FName,Extension : string;
begin FSplit(fullfilename,Directory,FName,Extension,true); Get_Dir:=Directory;end;

function  Get_Dirs(fullfilenamelist:string):string; 
var n,anz:longint; sh:string;
begin
  sh:=''; anz:=Anz_Item(fullfilenamelist,',','"');
  for n:= 1 to anz do
  begin
    sh:=sh+Get_Dir(Select_Item(fullfilenamelist,',','"',n));
    if (n<anz) then sh:=sh+',';
  end;
  Get_Dirs:=sh;
end;

function  Get_DirList(dirname:string; filelist:TStringList):integer;
const
{$IFDEF WINDOWS} c_dircmd = 'dir'; c_dirpara = '/b /ogne'; 
{$ELSE}          c_dircmd = 'ls';  c_dirpara = '-1';  {$ENDIF}
begin
//writeln('Get_DirList:',c_dircmd+' '+c_dirpara+' '+PrepFilePath(dirname));
  Get_DirList:=call_external_prog(LOG_NONE,c_dircmd+' '+c_dirpara+' '+PrepFilePath(dirname), filelist);
end;

function  GetTildePath(fullpath,homedir:string):string;
var sh:string;
begin
  sh:=StringReplace(fullpath,homedir,'~',[rfReplaceAll,rfIgnoreCase]);
  GetTildePath:=sh;
end;

function  PrepFilePath(fpath:string):string;
var i:integer; s:string; //Directory,FName,Extension:string; 
begin
  s:=SetDirSeparators(fpath);
  {$IFDEF UNIX} 
    if Pos(':',s)>0 then LOG_Writeln(LOG_ERROR,'filepath contains windows separator '+fpath);
  {$ENDIF}
//FSplit(fpath,Directory,FName,Extension,true); FName:=PrepFileName(FName); s:=Directory+PathDelim+FName+Extension;
  for i:= 1 to 3 do s:=StringReplace(s,PathDelim+PathDelim,PathDelim,[rfReplaceAll,rfIgnoreCase]); 
  PrepFilePath:=s;
end;

function  Select_Item(const strng,trenner,trenner2,dflt:string;itemno:longint) : string; 
const esc_char='\';
var   str,hs,tr1,tr2 : string; bcnt,trcnt : longint; dhk_start,esc_start,xx,ende : boolean;
  function detsep(s,seporig,notuse1,notuse2:string):string;
  (* find unique Byte as Seperator *)
  const sep_start=#$8f; sep_end=#$ff; 
  var   sep : char; ende : boolean;
  begin
    sep := sep_start; ende := false;
	while (ord(sep)<ord(sep_end)) and not ende do
	begin
	  if (Pos(sep,s)=0) and (sep<>notuse1) and (sep<>notuse2) then ende := true else sep:=char(ord(sep)+1);
	end;
	if not ende then detsep:=seporig else detsep:=sep;
  end; (* detsep *)
begin
  xx:=Length(trenner2)>0; 
  if Length(trenner) <=1 then tr1:=trenner  else tr1:=detsep(strng,trenner, ' ',' ');
  if Length(trenner2)<=1 then tr2:=trenner2 else tr2:=detsep(strng,trenner2,tr1,' '); 
  (* if not xx then tr2:=''; *) 
  str:=StringReplace(strng,trenner, tr1,[rfReplaceAll,rfIgnoreCase]);
  str:=StringReplace(str,  trenner2,tr2,[rfReplaceAll,rfIgnoreCase]);
  hs := ''; bcnt := 1; dhk_start := false; ende := false; esc_start := false;
  if Length(strng)>0 then trcnt := 1 else trcnt:=0;
  while (bcnt <= Length(str)) and not ende do
  begin
    if (xx) and ( (str[bcnt] = tr2) ) and (not esc_start) then dhk_start := not dhk_start;
    if (str[bcnt] = tr1) and (not dhk_start) then INC(trcnt);
	if (str[bcnt] <> esc_char) then esc_start := false;
    if (trcnt=itemno) and 
       ( ( str[bcnt] <> tr1)  or dhk_start) then hs:=hs+str[bcnt];
(* writeln(str[bcnt],' ',bcnt:2,' ',trcnt:2,'    '); *) 
	   INC(bcnt);
	if (itemno > 0) and (trcnt > itemno) then ende := true;
  end;
  hs:=StringReplace(hs,tr1,trenner, [rfReplaceAll,rfIgnoreCase]);
  if xx then hs:=StringReplace(hs,tr2,'',      [rfReplaceAll,rfIgnoreCase])
        else hs:=StringReplace(hs,tr2,trenner2,[rfReplaceAll,rfIgnoreCase]);
  if itemno <= 0 then system.Str(trcnt:0,hs);
  if (hs='') then hs:=dflt;
  Select_Item := hs;
end; 

function  Select_Item(const strng,trenner,trenner2:string; itemno:longint):string;
begin Select_Item:=Select_Item(strng,trenner,trenner2,'',itemno); end; 

function  Anz_Item(const strng,trenner,trenner2:string): longint;
var anz:longint; 
begin
  if Length(strng)>0 then
  begin if not Str2Num(Select_Item(strng,trenner,trenner2,0),anz) then anz:=0; end
  else anz := 0;
  Anz_Item := anz;
end;

function  Select_RightItems(const strng,trenner,trenner2:string;startitemno:longint) : string; 
var sh:string; n,m : longint;
begin
  sh:=''; m:=Anz_Item(strng,trenner,trenner2);
  for n := startitemno to m do
  begin
    sh:=sh+Select_Item(strng,trenner,trenner2,n);
	if n<m then sh:=sh+trenner;
  end;
  Select_RightItems := sh;
end;

function  Select_LeftItems(const strng,trenner,trenner2:string;enditemno:longint) : string; 
var sh:string; n,m : longint;
begin
  sh:=''; m:=enditemno;
  for n := 1 to m do
  begin
    sh:=sh+Select_Item(strng,trenner,trenner2,n);
	if n<m then sh:=sh+trenner;
  end;
  Select_LeftItems := sh;
end;

function  Locate_Value(const strng,search,tr1,tr2,tr3,tr4:string; var valoutstrng:string):boolean;
// e.g. strng: SMTP_Server=xxx.yyy.com&SMTP_FromAdr=postmaster@yyy.com&SMTP_ToAdr=admin@yyy.com
// tr1='&' tr2='' tr3='=' tr4='' 
// search='SMTP_FromAdr'
// valoutstrng: postmaster@yyy.com
var _found:boolean; n,anz:longint; sh:string;
begin
  valoutstrng:=''; _found:=false; n:=1; anz:=Anz_Item(strng,tr1,tr2);
  while (n<=anz) and (not _found) do	  
  begin
	sh:=Select_Item(strng,tr1,tr2,n);
	if (Pos(Upper(search),Upper(sh))>0) then 
	begin
	  valoutstrng:=Trimme(Select_RightItems(sh,tr3,tr4,2),3);
	  _found:=true;
	end;
	inc(n);
  end; // while
  Locate_Value:=_found;
end;

function  SepRemove(s:string):string;
var n:longint; sh:string;
begin
  sh:=s;
  for n:=0 to sep_max_c do sh:=StringReplace(sh,sep[n],' ',[rfReplaceAll,rfIgnoreCase]);
  SepRemove:=sh;
end;

function  StringListMinMaxValue(StrList:TStringList; fieldnr:word; tr1,tr2:string; var min,max:extended; var nk:longint):boolean;
var i:longint; e:extended; b1,b2:boolean; nkh,lgt:integer; sh:string;
begin
  min:=NaN; max:=NaN; b1:=false; b2:=false; nk:=0;
  if StrList.count>0 then
  begin
    min:=maxfloat; max:=-maxfloat;	// was maxextended , creates error on ARM (rpi) with FPC 2.6.4 
    for i:= 1 to StrList.count do 
    begin
	  sh:=Select_Item(StrList[i-1],tr1,tr2,fieldnr); // 12.3456
	  if Str2Num(sh,e) then
	  begin
	    lgt:=Length(sh); nkh:=lgt-Pos('.',sh); if nkh=lgt then nkh:=0;
	    if nkh>nk then nk:=nkh;
	    if e>max then begin max:=e; b1:=true; end;
		if e<min then begin min:=e; b2:=true; end;
	  end;
    end;
	if not b1 then max:=NaN; if not b2 then min:=NaN;
  end;
  StringListMinMaxValue:=(b1 and b2);
end;

procedure StringListSnap(StrListIn,StrListOut:TStringList; srchstrng:string);
var i:longint;
begin
  StrListOut.clear;
  for i:=1 to StrListIn.count do
  begin
    if Pos(srchstrng,StrListIn[i-1])=1 then StrListOut.add(StrListIn[i-1]);
  end;
end;

function  SearchStringInList(StrList:TStringList; srchstrng:string):string;
var sh:string; n:longint;
begin
  n:=1; sh:='';
  while (n<=StrList.Count) do
  begin
    if (Pos(srchstrng,StrList[n-1])>0) then begin sh:=StrList[n-1]; n:=StrList.Count; end;
    inc(n);  
  end;
  SearchStringInList:=sh;
end;

function  SearchStringInListIdx(StrList:TStringList; srchstrng:string; occurance,StartIdx:longint):longint;
// return idx, where searchstring occurs to the 'occurance' count. If not then return -1;
// if occurence>0 then search list from 1. to last record
// if occurence<0 then search list from end to 1. record
var n,ret,occhelp : longint; found:boolean; 
begin
  found:=false; ret:=-1; occhelp:=0;
  if occurance>0 then
  begin // von 1-Ende durchsuchen
    n:=StartIdx; if n<0 then n:=0;
    while (n<StrList.Count) and not found do
    begin
      if (Pos(srchstrng,StrList[n])>0) then 
	  begin 
	    inc(occhelp); 
	    if (occhelp=occurance) then begin found :=true; ret:=n; end; 
	  end;
      inc(n);  
    end;
  end;
  if occurance<0 then
  begin // von Ende-1 durchsuchen
    n:=StrList.Count-1; 
    while (n>=0) and not found do
    begin
      if (Pos(srchstrng,StrList[n])>0) then begin inc(occhelp); if (occhelp=abs(occurance)) then begin found :=true; ret:=n; end; end;
      dec(n);  
    end;
  end;
  SearchStringInListIdx:=ret;
end;

function  GiveStringListIdx(StrList:TStringList; srchstrng:string; var idx:longint; occurance:longint):boolean;
var ok:boolean;
begin
  idx:=SearchStringInListIdx(StrList, srchstrng, occurance,0); 
  if (idx>=0) and (idx<StrList.count) then ok:=true else ok:=false;  
  GiveStringListIdx:=ok;
end;

function  GiveStringListIdx(StrList:TStringList; srchstrngSTART,srchstrngEND:string; var idx:longint):boolean;
var ok,ende:boolean; sh:string; n,p1,p2:longint;
begin
  ok:=false; ende:=false; n:=1;
  repeat
    idx:=SearchStringInListIdx(StrList, srchstrngSTART, n,0); 
//  writeln(srchstrngSTART,' ',srchstrngEND,' ',idx);
    if (idx>=0) and (idx<StrList.count) then 
    begin
      sh:=StrList[idx]; p1:=Pos(srchstrngSTART,sh); p2:=Pos(srchstrngEND,sh);
      ok:=(p2>p1);
//    writeln(p1,' ',p2,' ',ok,' ',sh);
    end 
	else ende:=true;
	inc(n);
  until ok or ende;
  GiveStringListIdx:=ok;
end;

function  GiveStringListIdx2(StrList:TStringList; srchstrng:string; var idxStart,idxEnd:longint):boolean;
begin
  idxStart:=SearchStringInListIdx(StrList,srchstrng, 1,0);
  idxEnd:=  SearchStringInListIdx(StrList,srchstrng,-1,0);
  GiveStringListIdx2:=((idxStart<=idxEnd) and (idxStart>=0));
end;

function  SearchInConfigList(inifilbuf:TStringlist; section,name:string; secret:boolean; defaultstring:string; var line,secstart,secend:longint; var history:string): string;
  function SectionLineFound(var s:string):boolean; begin SectionLineFound:=((Pos('[',s)=1) and (Pos(']',s)=Length(s))); end;
  function SectionFound(var s:string; section:string):boolean; begin SectionFound:=(Pos('['+Upper(section)+']',Upper(s))=1); end;  
  function NameFound   (var s:string; name:   string):boolean; begin NameFound:=   (Pos(    Upper(name)+'=',   Upper(s))=1); end;   
var sect_found,name_found:boolean; s,sh,seclink:string; n:word; i:integer;
begin
  sh:=defaultstring; sect_found:=((section='') and (inifilbuf.Count>0)); 
  name_found:=false; seclink:=''; history:=history+'#'+section+'*';
  n:=0; line:=-1; secend:=-1; if sect_found then secstart:=0 else secstart:=-1; 
  while (n<inifilbuf.Count) and (not (sect_found and name_found)) do
  begin
//  writeln(n,' ',inifilbuf.Count);
    s:=inifilbuf[n];  
    if SectionLineFound(s) then
	begin
	  if sect_found then secend:=n-1;
	  sect_found:=SectionFound(s,section);
      if sect_found then 
	  begin 
	    secstart:=n; 
//	    writeln('section ',section,' ',sect_found);
	  end;
    end;
	if sect_found and  NameFound(s,'SECTIONLINK') then 
	begin
	  i:=Pos('=',s); seclink:=''; if i>0 then seclink:=copy(s,i+1,Length(s));
	end;
	if sect_found then name_found:=NameFound(s,name);
    if name_found and  sect_found then 
	begin
//	  inc(n);
	  line:=n;
	  i:=Pos('=',s); sh:=''; if i>0 then sh:=copy(s,i+1,Length(s));
	  while (n<inifilbuf.Count) do 
	  begin s:=inifilbuf[n]; if SectionLineFound(s) then secend:=n-1; inc(n); end;
	  if secend<0 then secend:=inifilbuf.Count-1; 
	end;
	inc(n);
//  writeln('found section:',sect_found,' name:',name_found,' ',sh);
  end;
  if (secend<0) then
  begin
    if sect_found then secend:=inifilbuf.Count else secstart:=-1;
  end;  
//writeln('#',seclink,'#',name_found);
  if (not name_found) and (seclink<>'') then
  begin
    LOG_Writeln(LOG_DEBUG,'SearchInConfigList: SECTIONLINK '+'['+seclink+'|'+name+'] is currently not supported  !!! '+history);
	if Pos('#'+seclink+'*',history)=0 
	  then sh:=SearchInConfigList(inifilbuf, seclink, name, secret, defaultstring, line, secstart, secend, history)
	  else LOG_WRITELN(LOG_ERROR,'SearchInConfigList: Loop in SECTIONLINK '+seclink+' '+history);
  end;
  SearchInConfigList:=sh;
end;

procedure String2StringList(str:string; StrList:TStringList);
var li:longint; sh:string;
begin
  sh:=StringReplace(str,CRLF,LF,[rfReplaceAll]);
  for li:= 1 to Anz_Item(sh,LF,'') do 
    StrList.add(Select_Item(sh,LF,'',li));
end;

function  StringList2String(StrList:TStringList; tr:string):string;
var li,anz:longint; sh:string;
begin
  sh:=''; anz:=StrList.count;
  for li:= 1 to anz do
  begin
//	sh:=sh+Trimme(StrList[li-1],3);	// 5:repl TAB with ' ', remove leading&trailing ' '
    sh:=sh+StrList[li-1];	
    if li<anz then sh:=sh+tr;
  end;
  StringList2String:=sh;
end;

function  StringList2String(StrList:TStringList):string;
begin StringList2String:=StringList2String(StrList,LineEnding); end;

function  StringList2TextFile(filname:string; StrListOut:TStringList):boolean;
{ Write StringList to TextFile }
var _ok:boolean; fn:string;
begin
  fn:=PrepFilePath(filname);
  try
	_ok:=true;
	StrListOut.SaveToFile(fn);
  except
    _ok:=false;
    LOG_Writeln(LOG_Error,'StringList2TextFile: could not write file '+fn);
  end;
  StringList2TextFile:=_ok;
end;

function  String2TextFile(filname:string; StrOut:string):boolean;
{ Write String to TextFile }
var _ok:boolean; _tl:TStringList; fn:string;
begin
  fn:=PrepFilePath(filname);
  _tl:=TStringList.create;
  try
  	String2StringList(StrOut,_tl);
	_ok:=true;
	_tl.SaveToFile(fn);
  except
    _ok:=false;
    LOG_Writeln(LOG_Error,'String2TextFile: could not write file '+fn);
  end;
  _tl.free;
  String2TextFile:=_ok;
end;

function  StringListAdd2List(StrList1,StrList2:TStringList; append:boolean):longword; //Adds StringList2 to Stringlist1. result is size of Stringlist in bytes
var n:longint; siz:longword;  
begin 
  siz:=0;
  if not append then
  begin // add to front
	for n := StrList2.count downto 1 do 
    begin
	  StrList1.insert(0,StrList2[n-1]); 
	  inc(siz,Length(StrList2[n-1]));
	end; 
  end
  else 
  begin // append
    for n := 1 to StrList2.count do 
    begin
	  StrList1.add(  StrList2[n-1]);
	  inc(siz,Length(StrList2[n-1]));
	end
  end;
  StringListAdd2List:=siz;
end;

function  StringListAdd2List(StrList1,StrList2:TStringList):longword; 
begin StringListAdd2List:=StringListAdd2List(StrList1,StrList2,true); end;

function  TextFile2StringList(filname:string; StrListOut:TStringList; var hash:string):boolean;
{ Read TextFile into a StringList (also possible from stdin, if filename='' ) }
var b:boolean; fn:string;
begin
  b:=true; fn:=PrepFilePath(filname);
  {$I-} 
  if FileExists(fn) then 
  begin
    StrListOut.LoadFromFile(fn); hash:=MD5Print(MD5String(StringList2String(StrListOut,''))); 
	Log_Writeln(LOG_DEBUG,'Read  from file: '+fn+' lines: '+Num2Str(StrListOut.count,0)+' hash: '+hash); 
  end 
  else 
  begin 
    b:=false; hash:=''; 
//	LOG_Writeln(LOG_Error,'TextFile2StringList: could not read file '+fn);
  end; 
  {$I+}
  TextFile2StringList:=b;
end;

function  TextFile2StringList(filname:string; StrListOut:TStringList; append:boolean; var hash:string):boolean;
var tl:TStringList; ok:boolean; 
begin
  ok:=false; 
  if append then
  begin
    tl:=TStringList.create;
    ok:=TextFile2StringList(filname,tl,hash);
	if ok then StringListAdd2List(StrListOut,tl);
	tl.free;
  end
  else 
  begin
    StrListOut.clear;
    ok:=TextFile2StringList(filname,StrListOut,hash);
  end;
  TextFile2StringList:=ok;
end;

function  TextFileContentCheck(file1,file2:string; mode:byte):boolean;
var ok:boolean; ts1,ts2:TStringList; i:longint; hash:string;
begin
  ok:=false;
  if FileExists(file1) and FileExists(file2) then
  begin
    ts1:=TStringList.create; ts2:=TStringList.create;
    if TextFile2StringList(file1,ts1,false,hash) then 
      if TextFile2StringList(file2,ts2,false,hash) then
	    if (ts1.count=ts2.count) and (ts1.count>0) then
        begin
	      ok:=true;
	      for i:= 1 to ts1.count do 
		  begin 
		    case mode of
		       1 : begin if Select_Item(ts1[i-1],' ','',1)<>Select_Item(ts2[i-1],' ','',1) then ok:=false; end;
		      else begin if ts1[i-1]<>ts2[i-1] then ok:=false; end;
		    end; // case
		  end;
        end;  
    ts1.free; ts2.free;
  end;
  TextFileContentCheck:=ok;
end;

function  TailFile(filname:string; LinesCount:longint):RawByteString;
var S:TStream; Validated,BytesToEnd:longint; rbs:RawByteString;
begin
  rbs:='';
  if FileExists(filname) then
  begin
	S:=TFileStream.Create(filname, fmOpenRead or fmShareDenyNone);
	try
	  S.Seek(0,soEnd);
      Validated:=0;
      while (Validated<LinesCount) and (S.Seek(-2,soCurrent)>=0) do
      begin
		if S.ReadByte=10 then inc(Validated);
      end;
      if Validated<LinesCount then S.Position:=0;
	  BytesToEnd:=S.Size-S.Position;
	  SetLength(rbs,BytesToEnd);
	  S.ReadBuffer(PByte(rbs)[0],BytesToEnd);
	finally
	  S.Free;
	end;
  end; // else LOG_Writeln(LOG_ERROR,'TailFile: does not exist '+filname);
  TailFile:=rbs;
end;

procedure TailFileFollow(filname:string; LinesCount:longint);
var timo:TDateTime; so,s:string;
begin
  s:=''; timo:=now;
  repeat
    so:=s;
    s:=TailFile(filname,LinesCount);
    if (s<>so) then 
    begin
//	  write(s,' 0x',HexStr(s));
	  write(s+#$0d);
	  SetTimeOut(timo,10000);
	end else sleep(50);
  until TimeElapsed(timo);
end;

function  GetRndTmpFileName(filhdr,extname:string):string;
var sh:string;
begin  
  sh:=c_tmpdir+'/'+filhdr+FormatDateTime('YYYYMMDDhhmmss',now)+extname;	// was '/tmp_'  ext: .txt
  GetRndTmpFileName:=PrepFilePath(sh); 
end;

procedure BIOS_EndIniFile; 
// https://github.com/graemeg/freepascal/blob/master/packages/fcl-base/src/inifiles.pp
var res:longint;
begin 
  res:=0;
  with IniFileDesc do 
  begin
    if ok then
    begin
      if inifilbuf.CacheUpdates then 
      begin
    	inifilbuf.CacheUpdates:=false;			// forces UpdateFile, if dirty
    	modifydate:=GetFileAge(inifilename);
      end;
      inifilbuf.free; 
      {$IFNDEF WINDOWS} 
      if FileExists(inifilename) then
      begin
		res:=fpChmod (inifilename,&600);
		if (res<>0) then LOG_Writeln(LOG_ERROR,'BIOS_EndIniFile: can not set perm '+inifilename+' 0x'+Hex(res,8));
	  end else res:=-1;
	  {$ENDIF}
    end;
    ok:=false;
  end;
end;

function  BIOS_DeleteKey(section,name:string):boolean;
begin 
  with IniFileDesc do 
  begin
	if ok then 
	begin
	  inifilbuf.DeleteKey(section,name); 
	  if (not inifilbuf.CacheUpdates) then modifydate:=GetFileAge(inifilename);
	end;
	BIOS_DeleteKey:=ok; 
  end; 
end;

procedure BIOS_EraseSection(section:string);
begin 
  with IniFileDesc do 
  begin
	if ok then 
	begin
	  inifilbuf.EraseSection(section); 
	  if (not inifilbuf.CacheUpdates) then modifydate:=GetFileAge(inifilename);
	end;
  end; // with
end;

procedure BIOS_CacheUpdate(upd:boolean);
begin with IniFileDesc do if ok then inifilbuf.CacheUpdates:=upd; end;

function  BIOS_CacheUpdate:boolean;
var upd:boolean;
begin
  with IniFileDesc do 
  begin
	if ok then upd:=inifilbuf.CacheUpdates else upd:=false; 
  end;
  BIOS_CacheUpdate:=upd;
end;

procedure BIOS_ReadIniFile(fname:string);
// e.g. BIOS_ReadIniFile('/etc/configfile.ini')
//var res:longint;
begin
  with IniFileDesc do
  begin
	inifilename:=PrepFilePath(fname); ok:=false; modifydate:=0;
    if inifilename<>'' then 
	begin
	  if not FileExists(inifilename) 
	    then call_external_prog(LOG_NONE,'touch '+inifilename); // just create on
	  {$IFNDEF WINDOWS} 
//		res:=fpChmod (inifilename,&600);
//		if (res<>0) then LOG_Writeln(LOG_ERROR,'BIOS_ReadIniFile: can not set perm '+inifilename+' 0x'+Hex(res,8));
	  {$ENDIF}
//	  writeln(inifilename,' ',FileExists(inifilename),' ',(inifilbuf=nil));
//	  if FileExists(inifilename) then 
	  begin // will be created, if file does not exist
	    if (inifilbuf<>nil) then inifilbuf.free;
	    inifilbuf:=TIniFile.Create(inifilename); 
	    inifilbuf.CacheUpdates:=false;				// force immediate UpdateFile after a change
		modifydate:=GetFileAge(inifilename);
		ok:=true;
      end
//    else LOG_Writeln(LOG_ERROR,'BIOS_ReadIniFile: no config file found '+inifilename);	  
	end;
  end;
end;

procedure BIOS_SetDfltSection(section:string);   begin IniFileDesc.dfltsection:=section; end;
procedure BIOS_SetDfltFlags(flags:s_BIOS_flags); begin IniFileDesc.dfltflags:=flags; end;

function  BIOS_GetIniString(section,name,default:string; flgs:s_BIOS_Flags):string;
// e.g. configfile.ini content:
// [SECNAME1]
// PARA1=Value 1234
// [SECNAME2]
// PARA1=Value 1
// PARAX=ValueX
// e.g. BIOS_GetIniString('SECNAME2','PARA1',false);
// return: 'Value 1'
// if Parameter is not found, then return default-string
var sh:string; bol:boolean; i64:int64; qw:qword; e:extended;
begin
  sh:=default; 
  with IniFileDesc do
  begin
	if ok then
	begin // read in and check. if checks not met then use default value. default val is not checked
	  if (section='') and (dfltsection<>'') then section:=dfltsection;
	  sh:=inifilbuf.ReadString(section,name,default);
	  if (BIOS_UnESC 		IN flgs) then sh:=SB_UnESC(sh);
	  if (BIOS_Printable 	IN flgs) then sh:=StringPrintable(sh);
	  if (BIOS_trim1 		IN flgs) then sh:=Trimme(sh,1);
	  if (BIOS_trim2 		IN flgs) then sh:=Trimme(sh,2);
	  if (BIOS_trim3 		IN flgs) then sh:=Trimme(sh,3);
	  if (BIOS_trim4 		IN flgs) then sh:=Trimme(sh,4);
	  if (BIOS_trim5 		IN flgs) then sh:=Trimme(sh,5);
// checks
	  if (BIOS_bool 		IN flgs) then if not Str2Bool(sh,bol)		then sh:=default;
	  if (BIOS_float 		IN flgs) then 
	  begin
	    sh:=Trimme(sh,3);
		if Str2Num(sh,e) then
		begin
		  if (BIOS_NonZero	IN flgs) and IsZero(e) 						then sh:=default; 
		  if (BIOS_lat		IN flgs) and (abs(e)> 90.0)					then sh:=default;
		  if (BIOS_lon		IN flgs) and (abs(e)>180.0)					then sh:=default;
		end else sh:=default;
	  end;
	  if (BIOS_int 			IN flgs) then 
	  begin
	  	sh:=Trimme(sh,3);
		if Str2Num(sh,i64) then
		begin
		  if (BIOS_NonZero	IN flgs) and (i64=0) 						then sh:=default; 
		  if (BIOS_1byte	IN flgs) and ((i64>  127) or (i64<  -128)) 	then sh:=default;
		  if (BIOS_2byte	IN flgs) and ((i64>32767) or (i64<-32768))	then sh:=default;
		  if (BIOS_4byte	IN flgs) and 
			((i64>2147483647) or (i64<-2147483648))						then sh:=default;
		end else sh:=default;
	  end;
	  if (BIOS_uint 		IN flgs) then 
	  begin
	  	sh:=Trimme(sh,3);
		if Str2Num(sh,qw) then
		begin
		  if (BIOS_NonZero	IN flgs) and (qw=0)							then sh:=default; 
		  if (BIOS_1byte	IN flgs) and (qw>$ff)						then sh:=default;
		  if (BIOS_2byte	IN flgs) and (qw>$ffff)						then sh:=default;
		  if (BIOS_4byte	IN flgs) and (qw>$ffffffff)					then sh:=default;
		end else sh:=default;
	  end;	  
	  if (BIOS_tstmp		IN flgs) then 
	  begin
	  	sh:=Trimme(sh,3);
	  	sh:=StringReplace(sh,'T',' ',[rfReplaceAll,rfIgnoreCase]);
		try StrToDateTime(sh); except sh:=default; end;
	  end;
	  if (BIOS_PrefDflt		IN flgs) and (default<>'')					then sh:=default;
	end; // else Log_Writeln(LOG_ERROR,'BIOS_GetIniString: INI-File not opened');
  end; // with
  if (sh='') then sh:=default;
  BIOS_GetIniString:=sh;
end;
function  BIOS_GetIniString(section,name,default:string):string;
begin BIOS_GetIniString:=BIOS_GetIniString(section,name,default,IniFileDesc.dfltflags); end;
function  BIOS_GetIniString(name,default:string):string;
begin BIOS_GetIniString:=BIOS_GetIniString(IniFileDesc.dfltsection,name,default,IniFileDesc.dfltflags); end;
function  BIOS_GetIniString(name,default:string; flgs:s_BIOS_Flags):string;
begin BIOS_GetIniString:=BIOS_GetIniString(IniFileDesc.dfltsection,name,default,flgs); end;

function  BIOS_GetIniNum(section,name:string; flgs:s_BIOS_Flags; default,minval,maxval:real):real;
var r:real; sh:string;
begin
  sh:=BIOS_GetIniString(section,name,'',flgs+[BIOS_float]);
  if (sh<>'') then
  begin
	if Str2Num(sh,r) then
	begin
	  if not IsNan(r) then
	  begin
		if not IsNan(minval) then if (r<minval) then r:=minval;
		if not IsNan(maxval) then if (r>maxval) then r:=maxval;
	  end else r:=default;
	end else r:=default;
  end else r:=default;
  BIOS_GetIniNum:=r; 
end;
function  BIOS_GetIniNum(section,name:string; default,minval,maxval:real):real;
begin BIOS_GetIniNum:=BIOS_GetIniNum(section,name,[],default,minval,maxval); end;
function  BIOS_GetIniNum(name:string; default,minval,maxval:real):real;
begin BIOS_GetIniNum:=BIOS_GetIniNum(IniFileDesc.dfltsection,name,[],default,minval,maxval); end;

//function  BIOS_SetIniString(section,name,value:string; secret,overwrite:boolean):boolean;
function  BIOS_SetIniString(section,name,value:string; flgs:s_BIOS_Flags):boolean;	
begin
  with IniFileDesc do
  begin
    if ok then 
    begin
      if (section='') and (dfltsection<>'') then section:=dfltsection;
      if not ((BIOS_noOVR 	IN flgs) and (BIOS_GetIniString(section,name,'',flgs)<>'')) then
      begin
      	if (BIOS_trim1 		IN flgs) then value:=Trimme(value,1);
	  	if (BIOS_trim2 		IN flgs) then value:=Trimme(value,2);
	  	if (BIOS_trim3 		IN flgs) then value:=Trimme(value,3);
	  	if (BIOS_trim4 		IN flgs) then value:=Trimme(value,4);
	  	if (BIOS_trim5 		IN flgs) then value:=Trimme(value,5);
        if (BIOS_DoESC 		IN flgs) then value:=BS_DoESC(value);
		inifilbuf.WriteString(section,name,value);
		if (not inifilbuf.CacheUpdates) then modifydate:=GetFileAge(inifilename);
	  end;
    end else Log_Writeln(LOG_ERROR,'BIOS_SetIniString: INI-File not opened');
  end;
  BIOS_SetIniString:=true;
end;
function  BIOS_SetIniString(section,name,value:string):boolean;	
begin BIOS_SetIniString:=BIOS_SetIniString(section,name,value,IniFileDesc.dfltflags); end;
function  BIOS_SetIniString(name,value:string):boolean;	
begin BIOS_SetIniString:=BIOS_SetIniString(IniFileDesc.dfltsection,name,value,IniFileDesc.dfltflags); end;

procedure BIOS_Test;
var fil:text; sh:string;
begin
  {$IFDEF UNIX} // just create a config file, only for demo reasons
    sh:=GetRndTmpFileName(ApplicationName,'.ini');
    assign (fil,sh); rewrite(fil);
    writeln(fil,'[SECNAME1]'); writeln(fil,'PARA1=Value 1234');
    writeln(fil,'[SECNAME2]'); writeln(fil,'PARA1=Value 1'); writeln(fil,'PARAX=ValueX');
    close(fil);
    writeln('Test start: reading the config file ',sh);
    BIOS_ReadIniFile(sh);	
    sh:=BIOS_GetIniString('SECNAME2','PARA1','DefaultValue',[]);
    writeln(' Read the parameter "PARA1" from section "SECNAME2"=',sh);
    sh:=BIOS_GetIniString('SECNAME1','PARA1','DefaultValue',[]);
    writeln(' Read the parameter "PARA1" from section "SECNAME1"=',sh);  
    sh:=BIOS_GetIniString('SECNAME2','PARA3','DefaultValue',[]);
    writeln(' Read the non existent parameter "PARA3" from section "SECNAME2"=',sh);
    writeln('Test end.');
    BIOS_EndIniFile;
  {$ENDIF}
end;

function  MStream2String(MStreamIn:TMemoryStream):string;
var s:string;
begin
  SetString(s,PAnsiChar(MStreamIn.memory),MStreamIn.size);
  MStream2String:=s;
end;

procedure String2MStream(MStreamIn:TMemoryStream; var SourceString:string);
begin
  MStreamIn.WriteBuffer(Pointer(SourceString)^, Length(SourceString));
  MStreamIn.Position := 0;
end;

function  MStream2File(filname:string; StreamOut:TMemoryStream):boolean;
var ok:boolean; fs:TFileStream;
begin
  ok:=true; fs:=TFileStream.Create(PrepFilePath(filname), fmCreate);
  if StreamOut.Size>0 then 
  begin StreamOut.Position:=0; fs.CopyFrom(StreamOut,StreamOut.Size); end else ok:=false;
  fs.free; 
  MStream2File:=ok;
end;

function  File2MStream(filname:string;StreamOut:TMemoryStream; var hash:string):boolean;
var b:boolean; fn:string;
begin
  b:=true; fn:=PrepFilePath(filname);
  {$I-}
  if FileExists(fn) then 
  begin
    StreamOut.LoadFromFile(fn); 
	hash:=MD5Print(MD5String(MStream2String(StreamOut))); 
  end
  else begin b:=false; hash:=''; end; 
  {$I+}
  File2MStream:=b;
end;

function  File2MString(filname:string; var OutString,hash:string):boolean;
var b:boolean; MStream:TMemoryStream; fn:string;
begin
  b:=true; fn:=PrepFilePath(filname);
  {$I-}
  if FileExists(fn) then 
  begin
    MStream:=TMemoryStream.create;
    MStream.LoadFromFile(fn); 
    OutString:=MStream2String(MStream);
	hash:=MD5Print(MD5String(OutString)); 
	MStream.free;
  end
  else begin b:=false; hash:=''; OutString:=''; end; 
  {$I+}
  File2MString:=b;
end;

procedure MemCopy(src,dst:pointer; size:longint); begin if size>0 then Move(src^, dst^, size); end; 
procedure MemCopy(src,dst:pointer; size,srcofs,dstofs:longint);
begin
  if size>0 then
  begin
    {$warnings off} 
      Move(pointer(longword(src)+srcofs)^, pointer(longword(dst)+dstofs)^, size);
	{$warnings on} 
  end;
end;

function GetVZ(dt1,dt2:TDateTime):integer; var vz:integer; begin if dt1>=dt2 then vz:=1 else vz:=-1; GetVZ:=vz; end;

function DeltaTime_in_ms(dt1,dt2:TDateTime):int64;
begin                                 
  DeltaTime_in_ms:=GetVZ(dt1,dt2)*MilliSecondsBetween(dt1,dt2);
end;

procedure LNX_KillProcesses(processlist:string; signal:word);
// IN:  '1234 5678'
var n,num,sig:longint; sh:string;
begin
//say(log_warning,'LNX_KillProcesses:'+processlist+':');
  for n:=1 to Anz_Item(processlist,' ','') do
  begin
	sh:=Trimme(Select_Item(processlist,' ','',n),3);
	if (sh<>'') then
	begin
	  case signal of
	  	1..31:	sig:=signal;
	  	else	sig:=1;			// -hup
	  end; // case
	  if Str2Num(sh,num) then 
	  begin
		call_external_prog(LOG_NONE,'kill -'+Num2Str(sig,0)+' '+sh);
//		say(log_warning,'kill -'+Num2Str(sig,0)+' '+sh);
	  end;
	end;
  end;
end;

function  LNX_GetProcessNumsByName(processname:string):string;
// IN:  'tail -f /var/log/syslog'
// OUT: '1234 5678'
var cmd,lst:string;
begin
  cmd:='pgrep -f "'+processname+'"';
  if (call_external_prog(LOG_ERROR,cmd,lst)<>0) then lst:='';
  lst:=Trimme(StringReplace(lst,LineEnding,' ',[rfReplaceAll,rfIgnoreCase]),4);
//say(LOG_WARNING,'LNX_GetProcessNumsByName: '+cmd+' '+lst);
  LNX_GetProcessNumsByName:=lst;
end;

function  HexStrFrm(str:string):string;
var n:longint; sh:string;
begin
  sh:='';
  for n:=1 to Length(str) do sh:=sh+Hex(ord(str[n]),2)+' ';
  HexStrFrm:=Trimme(sh,4);
end;

function  BTLE_GetBeaconHexStr(url:string; TXPower:byte):string;
// https://developers.google.com/nearby/notifications/get-started
// https://github.com/google/physical-web
// https://learn.adafruit.com/google-physical-web-uribeacon-with-the-bluefruit-le-friend/getting-started
// https://github.com/google/eddystone/tree/master/eddystone-url
// https://play.google.com/store/apps/details?id=com.uriio
(*
hciconfig hci0 up ; hciconfig hci0 noleadv ; hciconfig hci0 noscan
enable advertize: 	hciconfig hci0 leadv 3
disable advertize: 	hciconfig hci0 noleadv
*)
const ServiceID='D8FE'; 
var sh:string;
begin
  sh:=url; if (TXPower>3) then TXPower:=3;
//if (Pos('HTTP:',Upper(sh))>0) then LOG_Writeln(LOG_WARNING,'BTLE_GetBeaconHexStr: Nearby Notifications and Physical Web on Chrome require HTTPS URLs');	
  sh:=StringReplace(sh,'http://www.',	#$00,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'https://www.',	#$01,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'http://',		#$02,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'https://',		#$03,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.com/',    		#$00,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.org/',    		#$01,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.edu/',    		#$02,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.net/',    		#$03,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.info/',   		#$04,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.biz/',	    	#$05,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.gov/', 	   	#$06,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.com',    		#$07,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.org',	    	#$08,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.edu',  	  	#$09,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.net',	    	#$0a,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.info', 	   	#$0b,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.biz',	    	#$0c,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.gov',  	  	#$0d,[rfReplaceAll,rfIgnoreCase]);
//writeln('BTLE_GetBeaconHexStr: 0x'+HexStr(sh)+':'+StringPrintable(sh));
  sh:=StrHex('16'+ServiceID+'00')+char(TXPower)+sh;  
  if (Length(sh)>23) then
  begin
    sh:=''; LOG_Writeln(LOG_ERROR,'BTLE_GetBeaconHexStr: url to long: '+url); 
  end else sh:=StrHex('0303'+ServiceID+Hex(Length(sh),2))+sh;
//writeln('0x',HexStrFrm(sh));
  BTLE_GetBeaconHexStr:=sh;
end;
function  BTLE_StopBeaconStr:string;
begin
  BTLE_StopBeaconStr:=	'hciconfig hci0 noleadv >/dev/null 2>&1 ; '+
  						'hciconfig hci0 down >/dev/null 2>&1'
end;
function  BTLE_StopBeacon:boolean; // start async
begin BTLE_StopBeacon:=(RunProcess(BTLE_StopBeaconStr,'',false)=0); end;

function  BTLE_StartBeacon(hexstrng:string; TXPower:byte):boolean;
var _ok:boolean;
begin
  _ok:=(hexstrng<>'');
  if _ok then 
  begin
//	writeln('BTLE_StartBeacon: hcitool -i hci0 cmd 0x08 0x0008 '+Hex(Length(hexstrng),2)+' '+HexStrFrm(hexstrng));
    _ok:=(RunProcess(
    BTLE_StopBeaconStr+' ; '+
    'sleep 5 ; '+
  	'hciconfig hci0 up >/dev/null 2>&1 ; '+
  	'hciconfig hci0 noscan >/dev/null 2>&1 ; '+
  	'hciconfig hci0 leadv 3 >/dev/null 2>&1 ; '+
  	'hcitool -i hci0 cmd 0x08 0x0008 '+Hex(Length(hexstrng),2)+' '+HexStrFrm(hexstrng)+' >/dev/null 2>&1',
  	'',false)=0); // start async
  end else LOG_Writeln(LOG_ERROR,'BTLE_StartBeacon: no HexSting supplied');
  BTLE_StartBeacon:=_ok;
end;
function  BTLE_StartBeaconURL(url1,url2:string):longint;
// IN url1: https://www.google.com 
// IN url2: https://192.168.10.200
const TXPower=0; // 0-3	0:Lowest 3:high
var li:longint; sh:string;
begin 
//writeln('btle:',url1,'*',url2,'*');
  li:=0;
  if (li=0) then 
  begin 
	sh:=BTLE_GetBeaconHexStr(url1,TXPower); 
	if (sh<>'')	then li:=1;
  end;
  if (li=0) then
  begin
	sh:=BTLE_GetBeaconHexStr(url2,TXPower);
	if (sh<>'')	then li:=2;
  end;
  if (li>0) then BTLE_StartBeacon(sh,TXPower)
  		 	else LOG_Writeln(LOG_ERROR,'BTLE_StartBeaconURL: to long for beacon '+url1+' '+url2);
  BTLE_StartBeaconURL:=li; 
end;

function OS_ShellExitDesc(ErrNum:integer):string;
// http://www.tldp.org/LDP/abs/html/exitcodes.html
var sh:string;
begin
  sh:='';
  {$IFDEF UNIX}
	case ErrNum of
	  1:	sh:='General error';
	  2:	sh:='Misuse of shell builtins';	
	126:	sh:='Command invoked cannot execute';
	127:	sh:='command not found';
	128:	sh:='Invalid exit argument';
	130:	sh:='Script terminated by Control-C';
	else	sh:='unknown error'
	end; // case
  {$ENDIF}
  if (ErrNum<>0) then sh:=Trimme('('+Num2Str(ErrNum,0)+') '+sh,3);
  OS_ShellExitDesc:=sh;
end;

function  call_external_prog(typ:t_ErrorLevel; cmdline:string; receivelist:TStringList):integer;
// http://wiki.freepascal.org/Executing_External_Programs#Reading_large_output
// can return multiple lines in StringList
const BUF_SIZE=2048;
var exitStat,exitCode:integer; BytesRead:LongInt; 
	OutputStream:TStream; AProcess:TProcess; 
	Buffer: array[1..BUF_SIZE] of byte;
begin
//writeln('cmdline:',cmdline,':');
  if (cmdline<>'') then 
  begin
    AProcess:=TProcess.Create(nil);
	AProcess.Options:=[poUsePipes (* ,poWaitOnExit *)];	
	{$IFDEF WINDOWS}
      AProcess.Executable:='c:\windows\system32\cmd.exe';
      AProcess.Parameters.Add('/c');
    {$ELSE}
      AProcess.Executable:=sudo+'/bin/sh'; 
	  AProcess.Parameters.Add('-c');   
    {$ENDIF}		// and // was and
    if (typ<>LOG_NONE) or (Pos('2>',cmdline)<>0) then 
      AProcess.Options:=AProcess.Options+[poStderrToOutPut];
    AProcess.Parameters.Add(cmdline);

	AProcess.Execute;
	
    OutputStream:=	TMemoryStream.Create;
    repeat     
	  BytesRead:=AProcess.Output.Read(Buffer,BUF_SIZE);
	  OutputStream.Write(Buffer,BytesRead);
    until (BytesRead=0);
    
    OutputStream.Position:=0;
    receivelist.LoadFromStream(OutputStream);
    OutputStream.free;

    exitStat:=AProcess.exitStatus;	// reported by the OS
    exitCode:=AProcess.exitCode;	// exit code of the process
    AProcess.free; 
//	ShowStringlist(receivelist);	  
	with receivelist do
	begin
	  if (count>0) then 
	  begin
//		remove last trailing $00 (0 terminated string; remove last trailing LF
		receivelist[count-1]:=CSV_RemLastSep(receivelist[count-1],#$00);
		receivelist[count-1]:=CSV_RemLastSep(receivelist[count-1],LineEnding);
	  end; 
	end; // with

	if 	((typ< LOG_NONE)	and (exitCode<>0)) or 
	   	((typ<=LOG_NOTICE) 	and (exitCode= 0)) then
	begin
	  LOG_Writeln(typ,'ShellExec['+Num2Str(exitStat,0)+']: '+OS_ShellExitDesc(exitCode));
//	  LOG_ShowStringList(typ,receivelist);
	end;
  	  
  end else begin exitCode:=0; exitStat:=0; end;
  call_external_prog:=exitCode;
end;

function  call_external_prog(typ:t_ErrorLevel; cmdline:string; var receivestring:string):integer;
var exitCode:integer; receivelist:TStringList;
begin
  receivelist:=TStringList.create;
  exitCode:=call_external_prog(typ,cmdline,receivelist);
  receivestring:=StringList2String(receivelist,LineEnding);
  receivelist.free;
  call_external_prog:=exitCode;
end;

function  call_external_prog(typ:t_ErrorLevel; cmdline:string):integer;
// no content return
var exitCode,exitStat:integer; fpErrNo:longint; {$IFDEF WINDOWS} sh:string; {$ENDIF}
begin 
  {$IFDEF WINDOWS}
	exitCode:=call_external_prog(typ,cmdline,sh); 
  {$ELSE}
//	if (typ=LOG_ERROR)	and (Pos('2>',cmdline)=0) then cmdline:=cmdline+' 2>&1';
	if (typ=LOG_NONE)	and (Pos('2>',cmdline)=0) then cmdline:=cmdline+' 2>/dev/null';
    exitStat:=fpSystem(cmdline);		// faster than TProcess method
    fpErrNo :=fpgeterrno;
    exitCode:=wexitStatus(exitStat);
	if 	((typ< LOG_NONE)	and (exitCode<>0)) or 
	   	((typ<=LOG_NOTICE) 	and (exitCode= 0)) then
	begin
	  LOG_Writeln(typ,'shellExec['+
	  		Num2Str(exitStat,0)+'/'+
	  		Num2Str(fpErrNo,0)+']: '+OS_ShellExitDesc(exitCode));
  	end;
  {$ENDIF}
  call_external_prog:=exitCode;
end;
function  call_external_prog(cmdline:string):integer; 
begin call_external_prog:=call_external_prog(LOG_ERROR,cmdline); end;

function  RunScript(filname,para:string):integer;
var res:integer;
begin
  if FileExists(filname) then 
  begin
//	res:=call_external_prog(filname);
	res:=call_external_prog(filname+' '+para+' >' +filname+'.log 2>&1');
//	res:=call_external_prog(filname+' | tee ' +filname+'.log 2>&1');
  end
  else 
  begin 
	res:=-1; 
	LOG_Writeln(LOG_ERROR,'RunScript: file not exist '+filname); 
  end;
  RunScript:=res;
end;

function  RunScript(ts:TStringList; filname,para:string):integer;
var res:integer;
begin
  res:=-1;
//SAY_TL(LOG_INFO,ts); 
  if StringList2TextFile(filname,ts) then
  begin
	LNX_chmod	  (filname,&755); 
	res:=RunScript(filname,para)
  end else LOG_Writeln(LOG_ERROR,'RunScript: can not save '+filname);
  RunScript:=res;
end;

function  RunScript(ts:TStringList; para:string):integer;
var res:integer; filname:string;
begin
  {$IFDEF WINDOWS} 
	filname:=GetRndTmpFileName('RunScript_','.bat');
  {$ELSE}
	filname:=GetRndTmpFileName('RunScript_','.sh');
  {$ENDIF}
  res:=RunScript(ts,filname,para);
  DeleteFile(filname);
  RunScript:=res;
end;

function  RunProcess(filname,para:string; syncwait:boolean):integer;
// http://wiki.freepascal.org/Executing_External_Programs#Run_detached_program
var res,i:integer; tl:TStringList; RunProg:TProcess;
begin
  res:=-1; 
  if FileExists(filname) then 
  begin
    res:=0;
	RunProg:=TProcess.create(nil);
	RunProg.Executable:=filname;
	RunProg.Options:=[];
	RunProg.InheritHandles:=false;	// SF new 11.11.2018
	RunProg.ShowWindow:=swoShow;	// SF new 11.11.2018
//	Copy default environment variables including DISPLAY variable for GUI application to work
    for i:= 1 to GetEnvironmentVariableCount do
      RunProg.Environment.Add(GetEnvironmentString(i));	// SF new 11.11.2018
      
	RunProg.Parameters.Add(para);
	if syncwait then 
	begin
	  tl:=TStringList.Create;
	  RunProg.Options:=RunProg.Options+[poWaitOnExit];
	end;
	RunProg.Execute;
	if syncwait then 
	begin
	  tl.LoadFromStream(RunProg.Output);
	  tl.SaveToFile(filname+'.log');
	  tl.Free;
	end;
	RunProg.Free;
  end else LOG_Writeln(LOG_ERROR,'RunProcess: file not exist '+filname);
  RunProcess:=res;
end;

function  RunProcess(ts:TStringList; filname,para:string; syncwait:boolean):integer;
var res:integer;
begin
  res:=-1;
  if (filname='') then
  begin
  	{$IFDEF WINDOWS} 
	  filname:=GetRndTmpFileName('RunScript_','.bat');
  	{$ELSE}
	  filname:=GetRndTmpFileName('RunScript_','.sh');
	{$ENDIF}  
  end;
  if (ts.count>0) then
  begin
  	if StringList2TextFile(filname,ts) then 
  	begin
	  LNX_chmod		 (filname,&755); 
	  res:=RunProcess(filname,para,syncwait);
	end else LOG_Writeln(LOG_ERROR,'RunProcess: can not write '+filname); 
  end else LOG_Writeln(LOG_ERROR,'RunProcess: no commands given');
  RunProcess:=res;
end;

function  RunProcess(cmds,filname,para:string; syncwait:boolean):integer;
var res:integer; _tl:TStringList;
begin
  _tl:=TStringList.create;
  String2StringList(cmds,_tl);
  res:=RunProcess(_tl,filname,para,syncwait); 
  _tl.free;
  RunProcess:=res;
end;

procedure call_external_prog_Test;
const tr='#########################################################';
var res:integer; sh:string='';
begin
  writeln(tr); res:=call_external_prog(LOG_WARNING,	'TryThisUnknownCommand1', sh);	writeln(res:0,' ',sh);	
  writeln(tr); res:=call_external_prog(LOG_INFO,	'TryThisUnknownCommand2', sh);	writeln(res:0,' ',sh);	
{$IFDEF linux}  
  writeln(tr); res:=call_external_prog(LOG_ERROR,	'cat /etc/debian_version',sh);	writeln(res:0,' DebianVers:',sh); 
  writeln(tr); res:=call_external_prog(LOG_ERROR,	'ls -l /usr/local/xxsbin',sh);	writeln(res:0,' ',sh); 
  writeln(tr); res:=call_external_prog(LOG_ERROR,	'ls -l /usr/local/sbin',  sh);	writeln(res:0,' ',sh); 
{$ENDIF}  
  writeln(tr);
end;

function  LNX_SSHFSmount(site,pwd,mnt:string; var err:string):integer;
// experimental. currently not working 23.11.2018
// site IN: myuser@ftp.mysite.com:/
// pwd  IN: mypassword
// mnt  IN: ~/mnt/mysite
// res OUT: 0 -> OK; <>0 -> notOK  err string returns err desc
// https://www.digitalocean.com/community/tutorials/how-to-use-sshfs-to-mount-remote-file-systems-over-ssh
var res:integer;
begin
  if (site<>'') and (pwd<>'') and (mnt<>'') and (DirectoryExists(mnt)) then
  begin
    res:=call_external_prog(LOG_NONE,
    		''''+
//    		'umount '+mnt+' >/dev/null 2>&1; '+
    		'echo "'+pwd+'" | sshfs "'+site+'" "'+mnt+'" -o '+
//			'NumberOfPasswordPrompts=1,ServerAliveInterval=15,ServerAliveCountMax=3,'+
//    		'Compression=no,reconnect,'+
//    		'nonempty,sshfs_debug,debug,loglevel=debug,'+
			'workaround=rename,password_stdin,'+
    		'StrictHostKeyChecking=no,UserKnownHostsFile=/dev/null 2>&1'+'''',err);
  end else begin res:=-1; err:='LNX_SSHFSmount: missing param'; end;
//writeln('LNX_SSHFSmount:',res,' err:',err,':');
  LNX_SSHFSmount:=res;
end;

function  MD5_HashGET(filnam:string; var MD5hash:string):boolean;
// MD5_HashGET('/tmp/rfm.tgz',myhashstr)
//38398e53aa45f86427ada3e9331c24f9  rfm.tgz.md5
var ok:boolean;
begin
  if FileExists(filnam) then
  begin
    call_external_prog(LOG_NONE,'md5sum '+filnam,MD5hash); 
    MD5hash:=Select_Item(Trimme(MD5hash,4),' ','',1);
	ok:=(MD5hash<>'');
  end else ok:=false;
  MD5_HashGET:=ok;
end;

function  MD5_HashCreateFile(filnam,MD5filnam:string; var MD5hash:string):boolean;
// MD5_HashCreateFile('/tmp/rfm.tgz','/tmp/rfm.tgz.md5',myhashstr)
//38398e53aa45f86427ada3e9331c24f9  rfm.tgz.md5
var ok:boolean;
begin
  if FileExists(filnam) and DirectoryExists(Get_Dir(MD5filnam)) then
  begin
    call_external_prog(LOG_NONE,'md5sum '+filnam+' > '+MD5filnam,MD5hash); 
    MD5hash:=Select_Item(Trimme(MD5hash,4),' ','',1);
	ok:=(MD5hash<>'');
  end else ok:=false;
  MD5_HashCreateFile:=ok;
end;

function  MD5_HashGETFile(MD5filnam:string; var MD5hash:string):boolean;
//38398e53aa45f86427ada3e9331c24f9  rfm.tgz.md5
var ok:boolean; res:longint;
begin
  ok:=false;
  if (GetFileSize(MD5filnam)>0) then
  begin
    res:=call_external_prog(LOG_NONE,'tail '+MD5filnam,MD5hash); 
    MD5hash:=Select_Item(Trimme(MD5hash,4),' ','',1);
	ok:=(MD5hash<>'');
SAY(LOG_WARNING,'MD5_HashGETFile'+Num2Str(res,0)+':'+MD5filnam+':'+MD5hash+':'+Bool2Str(ok));
  end;
  MD5_HashGETFile:=ok;
end;

function  MD5_HashGETVersion(MD5filnam:string; var version:string; var versionmd5:real):boolean;
//38398e53aa45f86427ada3e9331c24f9  rfm.tgz.md5
//...
//0.952  version		<- via echo "0.952  version">>MD5filnam	// 
var ok:boolean; sh:string; 
begin
  ok:=false; versionmd5:=0; version:='';
  if (GetFileSize(MD5filnam)>0) then
  begin
    call_external_prog(LOG_NONE,'tail -1 '+MD5filnam,sh); 
    sh:=Trimme(sh,4);
    version:=Select_Item(sh,' ','',1);
	ok:=( (version<>'') and (Pos('VERSION',Upper(Select_Item(sh,' ','',2)))>0) );
//SAY(LOG_INFO,'MD5_HashGETVersion:'+MD5filnam+':'+sh+':'+version+':'+Bool2Str(ok));
	if ok then
	begin
	  ok:=Str2Num(version,versionmd5);
	  if not ok then begin version:=''; versionmd5:=0; end;
	end;
  end;
  MD5_HashGETVersion:=ok;
end;

function  MD5_Check(file1,file2:string):boolean;
//file1:	38398e53aa45f86427ada3e9331c24f9  rfm.tgz.md5
//file2:	38398e53aa45f86427ada3e9331c24f9  /tmp/rfm.tgz.md5
var ok:boolean; md5f1,md5f2:string;
begin
  ok:=false;
  if MD5_HashGETFile(file1,md5f1) and MD5_HashGETFile(file2,md5f2) then
	ok:=(Upper(md5f1)=Upper(md5f2));
  MD5_Check:=ok;
end;

procedure RPI_MaintDelEnv; begin RpiMaintCmd.EraseSection('RPIMAINT'); end;
procedure RPI_MaintSetEnvExec(EXECcmd:string);
begin
  RpiMaintCmd.WriteString('RPIMAINT','EXEC', 	EXECcmd);
end;
procedure RPI_MaintSetEnvFTP(FTPServer,FTPUser,FTPPwd,FTPLogf,FTPDefaults:string);
var sh:string;
begin
  sh:=FTPDefaults; if sh='' then sh:=CURLFTPDefaults_c;
//writeln('RPI_MaintSetEnvFTP:',FTPServer,':',FTPUser,':',FTPPwd,':',FTPLogf,':',sh);
  RpiMaintCmd.WriteString('RPIMAINT','FTPSRV', FTPServer);
  RpiMaintCmd.WriteString('RPIMAINT','FTPUSR', FTPUser);
  RpiMaintCmd.WriteString('RPIMAINT','FTPPWD', FTPPwd);
  RpiMaintCmd.WriteString('RPIMAINT','FTPLOG', FTPLogf);
  RpiMaintCmd.WriteString('RPIMAINT','FTPOPT', sh);
  CURL_RemoveProgressfile(FTPLogf+CURLpfext_c); 
end; 
procedure RPI_MaintSetEnvUPD(UpdPkgSrcFile,UpdPkgDstDir,UpdPkgDstFile,UpdPkgMaintDir,UpdPkgLogf:string);
begin
  RpiMaintCmd.WriteString('RPIMAINT','UPDPSF', UpdPkgSrcFile);
  RpiMaintCmd.WriteString('RPIMAINT','UPDPDD', UpdPkgDstDir);
  RpiMaintCmd.WriteString('RPIMAINT','UPDPDF', UpdPkgDstFile);
  RpiMaintCmd.WriteString('RPIMAINT','UPDMDIR',UpdPkgMaintDir);
  RpiMaintCmd.WriteString('RPIMAINT','UPDPLOG',UpdPkgLogf);
  CURL_RemoveProgressfile(UpdPkgLogf+CURLpfext_c); 
end;
procedure RPI_MaintSetEnvUPL(UplSrcPackageRemark,UplSrcFiles,UplDstDir,UplLogf:string);
begin // FTP-Upload
  RpiMaintCmd.WriteString('RPIMAINT','UPLREM', UplSrcPackageRemark);
  RpiMaintCmd.WriteString('RPIMAINT','UPLSF',  UplSrcFiles);
  RpiMaintCmd.WriteString('RPIMAINT','UPLDD',  UplDstDir);
  RpiMaintCmd.WriteString('RPIMAINT','UPLLOG', UplLogf);
  CURL_RemoveProgressfile(UplLogf+CURLpfext_c); 
end;
procedure RPI_MaintSetEnvDWN(DwnSrcDir,DwnlSrcFiles,DwnDstDir,DwnLogf:string);
begin // FTP-Download
  RpiMaintCmd.WriteString('RPIMAINT','DWNSD',  DwnSrcDir);
  RpiMaintCmd.WriteString('RPIMAINT','DWNSF',  DwnlSrcFiles);
  RpiMaintCmd.WriteString('RPIMAINT','DWNDD',  DwnDstDir);
  RpiMaintCmd.WriteString('RPIMAINT','DWNLOG', DwnLogf);
  CURL_RemoveProgressfile(DwnLogf+CURLpfext_c); 
end;

function  LNX_ErrDesc(errno:longint):string; 
begin LNX_ErrDesc:='('+Num2Str(errno,0)+') '+StrError(errno); end;

function  FPC_ErrDesc(ErrNum:integer):string;
var sh:string;
begin
  case ErrNum of
        0 : sh:='Program terminated normally';
        1 : sh:='Invalid function number';
        2 : sh:='File not found';
        3 : sh:='Path not found';
        4 : sh:='Too many open files';
        5 : sh:='File access denied';
        6 : sh:='Invalid file handle';
		8 : sh:='Insufficient memory';
       12 : sh:='Invalid file access mode';
       15 : sh:='Invalid drive number';
       16 : sh:='Cannot remove current directory';
       17 : sh:='Cannot rename accross drives';
      100 : sh:='Disk read error';
      101 : sh:='Disk write error';
      102 : sh:='File not assigned';
      103 : sh:='File not open';
      104 : sh:='File not open for input';
      105 : sh:='File not open for output';
      106 : sh:='Invalid numeric format';
      150 : sh:='Disk is write protected';
      151 : sh:='Bad drive request struct length';
      152 : sh:='Drive not ready';
      153 : sh:='Unknown Command';
      154 : sh:='CRC error in data';
      155 : sh:='Bad drive request structure length';
      156 : sh:='Disk seek error';
      157 : sh:='Unknown media type';
      158 : sh:='Sector not found';
      159 : sh:='Printer out of paper';
      160 : sh:='Device write fault';
      161 : sh:='Device read fault';
      162 : sh:='Hardware failure';
      200 : sh:='Division by zero';
      201 : sh:='Range check error';
      202 : sh:='Stack overflow error';
      203 : sh:='Heap overflow error';
      204 : sh:='Invalid pointer operation';
      205 : sh:='Floating point overflow';
      206 : sh:='Floating point underflow';
      207 : sh:='Invalid floating point operation';
      208 : sh:='Overlay manager not installed';
      209 : sh:='Overlay file read error';
      210 : sh:='Object not initialized';
      211 : sh:='Call to abstract method';
      212 : sh:='Stream register error';
      213 : sh:='Collection index out of range';
      214 : sh:='Collection overflow error';
	  215 : sh:='Arithmetic overflow error';
	  216 : sh:='General Protection fault';
	  217 : sh:='invalid operation code';
	  218 : sh:='Invalid value specified';
	  219 : sh:='Invalid typecast';
	  222 : sh:='Variant dispatch error';
	  223 : sh:='Variant array create';
	  224 : sh:='Variant is not an array';
	  225 : sh:='Var Array Bounds check error';
	  227 : sh:='Assertion failed error';
	  229 : sh:='Safecall error check';
	  231 : sh:='Exception stack corrupted';
	  232 : sh:='Threads not supported';
      255 : sh:='Aborted via ^C';
      300 : sh:='file IO error';
      301 : sh:='non-matched array bounds';
      302 : sh:='non-local procedure pointer';
      303 : sh:='procedure pointer out of scope';
      304 : sh:='function not implemented';
      305 : sh:='breakpoint error';
      306 : sh:='break by ^C';
      307 : sh:='break by ^Break';
      308 : sh:='break by other process';
      309 : sh:='no floating point coprocessor';
      310 : sh:='invalid variant type operation';
      else  sh:='unknown errornum';
  end;
  if ErrNum<>0 then sh:='('+Num2Str(ErrNum,0)+') '+sh;
  FPC_ErrDesc:=sh;
end; // FPC_ErrDesc

function  CURL_ErrDesc(ErrNum:longint):string; // translate some error codes
var sh:string;
begin
  case ErrNum of
  	  0: sh:='ok';
      1: sh:='Unsupported protocol';
	  2: sh:='Failed to initialize';
	  3: sh:='URL malformed';
	  4: sh:='feature not available';
	  5: sh:='Couldn''t resolve proxy';
	  6: sh:='Couldn''t resolve host';
	  7: sh:='Failed to connect to host';
	  8: sh:='FTP weird server reply';
	  9: sh:='FTP access denied';
	 10: sh:='FTP accept failed';
	 11: sh:='FTP weird PASS reply';
	 12: sh:='FTP port timeout';
	 13: sh:='FTP weird PASV reply';
	 14: sh:='FTP weird 227 format';
	 15: sh:='FTP can''t resolve host IP';
	 16: sh:='HTTP/2 error';
	 17: sh:='FTP couldn''t set binary';
	 18: sh:='Partial file';
	 19: sh:='FTP couldn''t download/access the given file';
	 21: sh:='FTP quote error';
	 22: sh:='HTTP page not retrieved';
	 23: sh:='Write error';
	 25: sh:='FTP couldn''t STOR file';
	 26: sh:='Read error';
	 27: sh:='Out of memory';
	 28: sh:='Operation timeout';
	 30: sh:='FTP PORT failed';
	 31: sh:='FTP could not use REST';
	 33: sh:='HTTP range error';
	 34: sh:='HTTP post error';
	 35: sh:='SSL connect error';
	 36: sh:='FTP bad download resume';
	 37: sh:='couldn''t read file. Failed to open the file. Permissions?';
	 38: sh:='LDAP can not bind';
	 39: sh:='LDAP search failed';
	 42: sh:='aborted callback';
	 43: sh:='bad function argument';
	 45: sh:='interface error';
	 47: sh:='too many redirects';
	 48: sh:='unknown option specified';
	 49: sh:='Malformed telnet option';
	 51: sh:='The peer''s SSL certificate or SSH MD5 fingerprint was not OK';
	 52: sh:='The server didn''t reply anything';
	 53: sh:='SSL crypto engine not found';
	 54: sh:='can not set SSL crypto engine';
	 55: sh:='failed sending network data';
	 56: sh:='failure in receiving network data';
	 58: sh:='problem with local certificate';
	 59: sh:='can not use specified SSL cipher';
	 60: sh:='Peer certificate can not be authenticated with known CA certificate';
	 61: sh:='Unrecognized transfer encoding';
	 62: sh:='Invalid LDAP URL';
	 63: sh:='Maximum file size exceeded';
	 64: sh:='Requested FTP SSL level failed';
	 65: sh:='Sending the data requires a rewind that failed';
	 66: sh:='Failed to initialize SSL Engine';
	 67: sh:='failed to log in';
	 68: sh:='File not found on TFTP server';
	 69: sh:='Permission problem on TFTP server';
	 70: sh:='Out of disk space on TFTP server';
	 71: sh:='Illegal TFTP operation';
	 72: sh:='Unknown TFTP transfer ID';
	 73: sh:='File already exists (TFTP)';
	 74: sh:='No such user (TFTP)';
	 75: sh:='Character conversion failed';
	 76: sh:='Character conversion functions required';
	 77: sh:='Problem with reading the SSL CA cert';
	 78: sh:='The resource referenced in the URL does not exist';
	 79: sh:='An unspecified error occurred during the SSH session';
	 80: sh:='Failed to shut down the SSL connection';
	 82: sh:='Could not load CRL file, missing or wrong format';
	 83: sh:='TLS certificate issuer check failed';
	 84: sh:='The FTP PRET command failed';
	 85: sh:='RTSP: mismatch of CSeq numbers';
	 86: sh:='RTSP: mismatch of Session Identifiers';
	 87: sh:='unable to parse FTP file list';
	 88: sh:='FTP chunk callback reported error';
	 89: sh:='No connection available, the session will be queued';
	 90: sh:='SSL public key does not matched pinned public key';
	 91: sh:='Invalid SSL certificate status';
	 92: sh:='Stream error in HTTP/2 framing layer';
	else sh:='unknown errornum';
  end; // case
  if ErrNum<>0 then sh:='('+Num2Str(ErrNum,0)+') '+sh;
  CURL_ErrDesc:=sh;
end;

function  PV_Progress(progressfile:string):integer;
// asumes that pv output is redirected to progressfile with -n option
// e.g. dd if=/dev/urandom bs=1M count=100 | pv -n -s 100m 2>/tmp/pv.out | dd of=/dev/null
// percentage is in /tmp/pv.out and is assigned to function result res
// requires apt-get install pv
var res:integer; sh:string;
begin
  res:=-1;
  if call_external_prog(LOG_NONE,'tail -n 1 '+progressfile,sh)=0 then 
  begin
    sh:=Select_Item(sh,#$0a,'',1);
    if not Str2Num(sh,res) then res:=-1;
  end;
  PV_Progress:=res;
end;

function  CURLcmdCreate(usrpwd,proxy,ofil,uri:string; flags:s_rpimaintflags):string;
var cmd:string;
begin
  cmd:='curl ';
//if  	  UpdSUDO			IN flags	then cmd:='sudo '+cmd; 
  if not (UpdNoRedoRequest	IN flags) 	then cmd:=cmd+'-Lf '; 
  if not (UpdNoFTPDefaults 	IN flags) 	then cmd:=cmd+CURLFTPDefaults_c+' ';
  if UAgent 				IN flags 	then cmd:=cmd+'-A "User-Agent: '+UAgentDefault+'" ';
  if usrpwd<>'' 					  	then cmd:=cmd+'-u '+usrpwd+' ';
  if proxy<>''							then cmd:=cmd+'-x '+proxy+' ';
  if UpdVerbose 			IN flags	then cmd:=cmd+'-v ';
  if UpdSSL     			IN flags	then cmd:=cmd+CURLSSLDefaults_c+' ';
  if not (UpdNoCreateDir 	IN flags) 	then cmd:=cmd+'--ftp-create-dirs ';
  if ofil<>'' then 
  begin
    if UpdNewerOnly     	IN flags	then cmd:=cmd+'-z '+ofil+' ';	// additional to -o <ofile>
    										 cmd:=cmd+'-o '+ofil+' ';
  end;
  cmd:=cmd+uri;
  CURLcmdCreate:=cmd;
end;

function  CURL_ProgressUpdateHook(lvl:t_ErrorLevel; msgtype:MSG_Type_t; msg:string):longint; 
// e.g. update external OLED, WEBGuiMsgBoard...
var res:longint; xferdata,perc,filnam:string;
begin 
//1   2   3        4 5     6            7           8         9        10       11           12
//% Total % Received % Xferd AverageDload SpeedUpload TimeTotal TimeSpent TimeLeft CurrentSpeed
// "96 52.3M 96,50.3M 0 0 3101k 0,0:00:17 0:00:16 0:00:01 3549k","filename"
  res:=0;
  xferdata:=Select_Item(msg,',','"',1); filnam:=Select_Item(msg,',','"',2); 
  perc:=Select_Item(xferdata,',','',1)+'%'; 
  writeln(#$0d+'Here is my function, which handles curl progress information asynchronously: '+filnam+' '+perc);
//e.g. code to update OLED Display
  CURL_ProgressUpdateHook:=res;
end;

function  CURL_ProgressThread(ptr:pointer):ptrint;
// e.g. this thread could update a Gauge on an external OLED display
var term:boolean; res:longint; 	sh:string;
begin
  Thread_SetName('CURL_Progress'); 
  if ptr<>nil then
  begin
//	SAY(LOG_DEBUG,'CURL_ProgressThread: start');
	with Thread_Ctrl_ptr(ptr)^ do 
	begin 
	  repeat
		if CURL_DoProgressAction(Thread_Ctrl_ptr(ptr)^,term) then
    	begin //														  
    	  if (CURL_ProgressUpdateHook_ptr<>nil) then
    	  begin
(*% Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed                             
ThreadParaStr[4]:
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100   168    0   168    0     0    132      0 --:--:--  0:00:01 --:--:--   132
  1 52.3M    1  920k    0     0   352k      0  0:02:32  0:00:02  0:02:30  964k
 16 52.3M   16 8719k    0     0  1889k      0  0:00:28  0:00:04  0:00:24 2950k
 96 52.3M   96 50.3M    0     0  3101k      0  0:00:17  0:00:16  0:00:01 3549k
100 52.3M  100 52.3M    0     0  3119k      0  0:00:17  0:00:17 --:--:-- 3490k
100 52.3M  100 52.3M    0     0  3119k      0  0:00:17  0:00:17 --:--:-- 3490k *)
//say(LOG_INFO,'CURL_ProgressThread:'+ThreadParaStr[4]);
			sh:=Trimme(RM_CRLF(ThreadParaStr[4]),4);
//e.g.: 96 52.3M 96,50.3M 0 0 3101k 0,0:00:17 0:00:16 0:00:01 3549k					
    		res:=CURL_ProgressUpdateHook_ptr(
    				LOG_INFO,
    				curlprogmsg,		
    				'"'+sh+'"'+					// csv progress-string: "96 52.3M ..."
    				','+						// csv
    				'"'+ThreadParaStr[2]+'"'	// "filename"
    			);
    		if (res<>0) then ;					// react on exit code, future use
    											// currently only 0 supported
    	  end;
		end;
	  until term or TerminateProg;
	  delay_msec(250);	// let other Threads terminate
//	  SAY(LOG_DEBUG,'CURL_ProgressThread: end');
	end; // with
  end else Log_Writeln(LOG_ERROR,'CURL_ProgressThread: no valid ctlstruct');
  EndThread; 
  CURL_ProgressThread:=0;
end;

procedure CURL_SetPara(var CurlThCtl:Thread_Ctrl_t; info,curlcmd,logfile,filenamelist,dirname:string; updintervall_ms:integer; flgs:s_rpimaintflags);
begin 
  if (CURL_ProgressUpdateHook_ptr<>nil)
	then Thread_InitStruct2(CurlThCtl,@CURL_ProgressThread)	// routine for handling progress bar
	else Thread_InitStruct2(CurlThCtl,nil); 				// routine disabled 
   
  with CurlThCtl do 
  begin
    ThreadInfo:=info;
  	if (UpdCleanUP 		IN flgs)	then ThreadPara[1]:=1 else ThreadPara[1]:=0; // cleanup log-/progressfile yes/no
  	if (UpdShowThInfo	IN flgs)	then ThreadPara[2]:=1 else ThreadPara[2]:=0; 
  	ThreadPara[0]:=updintervall_ms;
  	if updintervall_ms< 1500 then ThreadPara[0]:= 1500;
  	if updintervall_ms>15000 then ThreadPara[0]:=15000;
  	SetTimeOut(ThreadTimeOut,30000);	
	if logfile='' then
	begin
	  ThreadParaStr[0]:=GetRndTmpFileName('curl_','.log');	// random logfilename
	  ThreadPara[1]:=1;										// cleanup log-/progressfile
	end else ThreadParaStr[0]:=PrepFilePath(logfile);
	ThreadParaStr[1]:=	 ThreadParaStr[0]+CURLpfext_c;		// progressfile
	ThreadParaStr[2]:=	 filenamelist;						// list of filenames that are transferred
	ThreadParaStr[3]:=	 dirname;							// dir info
	ThreadParaStr[4]:=	 '';								// reserved, progress threadinfo will be returned
	
	if (curlcmd<>'') then 
	begin
	  ThreadCmdStr:=curlcmd;
	  if (UpdLogAppend	IN flgs)	then ThreadCmdStr:=ThreadCmdStr+' >>'
	  								else ThreadCmdStr:=ThreadCmdStr+' >';
	  ThreadCmdStr:=ThreadCmdStr+'"'+ThreadParaStr[0]+'"';	// logfile
	  
	  if not (UpdNoProgressBar IN flgs) then
		ThreadCmdStr:=ThreadCmdStr+' 2>"'+ThreadParaStr[1]+'"';// progressfile
	end else Log_Writeln(LOG_ERROR,'CURL_SetPara: no valid curlcmd');
  end; // with 
end;

function  CURL_DoProgressAction(var CurlThCtl:Thread_Ctrl_t; var terminate:boolean):boolean;
var ok:boolean;
begin
  with CurlThCtl do 
  begin 
	ok:=((ThreadProgressOld<>ThreadProgress) and ThreadRunning (*and FileExists(ThreadParaStr[1])*));
	if ok then
    begin
	  ThreadProgressOld:=ThreadProgress;
      SetTimeOut(ThreadTimeOut,30000);			// if progress changes, retrig timeout  
      if not TermThread then delay_msec(ThreadPara[0])	// interval in ms
      					else delay_msec(100);
    end;
    terminate:=(TimeElapsed(ThreadTimeOut) or (not ThreadRunning) or TerminateProg);
//	if terminate then writeln(LOG_INFO,'terminate: ',ThreadRunning,' Telapsed',TimeElapsed(ThreadTimeOut),' ok:',ok);
  end; // with
  CURL_DoProgressAction:=ok;
end;

procedure CURL_RemoveProgressfile(progressfile:string);
var sh:string;
begin if progressfile<>'' then call_external_prog(LOG_NONE,'rm -f '+progressfile,sh) end;

function  CURLThread(ptr:pointer):ptrint;
// executes curl thread
begin
  if ptr<>nil then
  begin
	Thread_SetName('CURL_Thread'); 
	with Thread_Ctrl_ptr(ptr)^ do 
	begin 	
//	  SAY(LOG_INFO,'CURL+: '+ThreadCmdStr);
      ThreadRetCode:=call_external_prog(LOG_NONE,ThreadCmdStr,ThreadRetStr);	// sync. call
//	  if (ThreadRetCode<>0) then LOG_Writeln(LOG_ERROR,'CURLThread: '+CURL_ErrDesc(ThreadRetCode));
	  TermThread:=true;					// signal that Thread will end soon
      delay_msec(ThreadPara[0]); 		// give Threads time to react on termination
	  ThreadRunning:=false; 			// signal final termination to external Threads
	end; // with
  end else Log_Writeln(Log_ERROR,'CURLThread: no parameter pointer supplied');
  EndThread; 
  CURLThread:=0;
end;

function  CURL(var CurlThCtl:Thread_Ctrl_t):integer;
var cleanup:boolean; ival_ms:longint; logf,pfil:string;  

  function  CURL_Progress:integer;
  var sh:string; p:integer;
  begin        
    p:=-1; sh:=TailFile(pfil,1);
    with CurlThCtl do
    begin
	  if (sh<>'') then
      begin
      	sh:=RM_CRLF(Select_Item(sh,#$0d,'',Anz_Item(sh,#$0d,'')));
      	if (sh<>'') then
      	begin
		  ThreadParaStr[4]:=#$0d+sh;	// last bar available a ThreadParamStr 
	  	  write(ThreadParaStr[4]);
	  	end;
      	sh:=Trimme(copy(sh,1,3),3);
      	if Str2Num(sh,p) and (p>=0) and (p<=100) 
      	  then begin if (p>=ThreadProgress) then ThreadProgress:=p; end 
      	  else p:=-1;
	  end;
	end; // with
    CURL_Progress:=p;
  end; // CURL_Progress
  
begin  
  with CurlThCtl do 
  begin 
    if (ThreadPara[2]<>0) then Thread_ShowStruct(CurlThCtl);
	logf:=ThreadParaStr[0];			// logfile
	pfil:=ThreadParaStr[1];			// progress file	
	ival_ms:=ThreadPara[0] div 2;	// interval in ms
	cleanup:=(ThreadPara[1]<>0);	// delete log-/progressfile after execution
	CURL_RemoveProgressfile(pfil); 
	CURL_RemoveProgressfile(logf);
	pfil:=RemoveChar(pfil,'"');
	if (pfil<>'') then
	begin
	  Thread_Start(CurlThCtl,@CURLThread,@CurlThCtl,250,0);	// start curl data transfer
	  if ThreadFunc<>nil then	// do something async with the progress information
	  begin
	    delay_msec(5000);	// wait 5 sec, progress file will deliver reliable values
		BeginThread(ThreadFunc,@CurlThCtl);	
	  end;
	  repeat
		CURL_Progress;
		if (ThreadRunning) 	then delay_msec(ival_ms);
	  	if (not TermThread) then delay_msec(ival_ms);
	  until (not ThreadRunning) or TimeElapsed(ThreadTimeOut) or TerminateProg;
	  
//	  Thread_End(CurlThCtl,0);
	  if (ThreadRetCode<>0) then LOG_Writeln(LOG_ERROR,'CURL: '+CURL_ErrDesc(ThreadRetCode));
	  if cleanup then 
	  begin
	  	delay_msec(100);
//		say(log_info,'CURL cleanup:'+pfil+':'+logf);
	    CURL_RemoveProgressfile(pfil); 
	    CURL_RemoveProgressfile(logf);
	  end;
	  write(#$0d);
	end;
	CURL:=ThreadRetCode;
  end; // with
end;

procedure CURL_Test;
// shows usage curl with progress info update 
const filnam_c='52241088c1da59a359110d39c1875cda56496764';
begin	
  CURL_ProgressUpdateHook_ptr:=@CURL_ProgressUpdateHook;	// install ext. routine
	
  CURL_SetPara(	CurlThreadCtrl,				// control structure, has to be defined globally
				'CURL_Test',				// give the curl task a name
  				CURLcmdCreate(
  						'',					// no usrpwd
  						'',					// no proxyserver
  						'/dev/null',		// dir for outfile (demonstration, just drop all files)
						'https://github.com/Hexxeh/rpi-firmware/tarball/{'+filnam_c+'}',// files2download
  						[UpdNoCreateDir,UpdNoFTPDefaults]	// curl flags
  				),
  				'/tmp/curltest.log',		// logfile
  				filnam_c,					// filenames
  				'/dev/null',				// target dir
  				2500,						// update every 2.5s (2500ms)
  				[UpdShowThInfo]				// additional flags
  			  );
  with CurlThreadCtrl do
  begin
  	writeln(ThreadCmdStr);									// curlcmd: just show what we do 
  	ThreadRetCode:=CURL(CurlThreadCtrl);					// initiate curl download
  	writeln('CURL_Test: RetCode: ',ThreadRetCode);
  end; // with
  
  CURL_ProgressUpdateHook_ptr:=nil;							// deinstall ext. routine
end;

procedure RPI_MaintSetVersions(versmin,versmax:real); 
begin 
  RPI_MaintMinVersion:=versmin; 
  RPI_MaintMaxVersion:=versmax; 
end;

function  RPI_Maint(UpdFlags:s_rpimaintflags; var CurlThCtl:Thread_Ctrl_t):integer; 
const test_c=false; test2_c=false; c_maxp=10; 
type  t_parr = array[1..c_maxp] of string;
var   p2:t_parr; j,res:integer; i64:int64; r,version_new_md5,version_old_md5:real; 
	  noMD5Chk,test,test2:boolean;
	  flgs:s_rpimaintflags; cmd:t_rpimaintflags; 
	  tl:TStringList;
	  sh,filnam,DfltMaintDir,cdmod,usrpwd,cmds,cmdsf,version,versold,
	  FTPServer,FTPUser,FTPPwd,FTPlogf,FTPOpts,
	  UpdPkgSrcFile,UpdPkgSrcDir,UpdPkgDstFile,UpdPkgDstDirAndFile,
	  UpdPkgMaintDir,UpdPkgMD5FileOld,UpdPkgDstDir,UpdPkglogf,
	  UplSrcFiles,UplSrcPkgRem,UplDstDir,Upllogf,DwnSrcDir,DwnSrcFiles,DwnDstDir,DwnLogf:string;
	  
  function  cmdget(var p:t_parr):string; var i:integer; sh:string; begin sh:=p[1]; for i:=2 to c_maxp do sh:=sh+' '+p[i]; cmdget:=Trimme(sh,4); end;
  procedure parr_clean(var p:t_parr); var i:integer; begin for i:=1 to c_maxp do p[i]:=''; end;
  function  parr_gets (var p:t_parr):string; var i:integer; sh:string; begin sh:=''; if test2 then for i:=1 to c_maxp do if p[i]<>'' then sh:=sh+p[i]+' '; parr_gets:=Trimme(sh,3); end;
  procedure parr_show (s:string; var p:t_parr); begin if test2 then say(LOG_WARNING,'maint: '+s+':'+parr_gets(p)+':'); end;
  function  MD5Chk(oklvl,errlvl:T_errorlevel; file1,file2:string):boolean;
  var ok:boolean; sh:string;
  begin
    ok:=MD5_Check(file1,file2); sh:='MD5_Check: '+file1+' '+file2+' same='+Bool2YN(ok);
    if ok then say(oklvl,sh) else say(errlvl,sh);
    MD5Chk:=ok;
  end;
    
  function  cmd_do(p:t_parr):integer;
  var cmd:string; res:integer; page3:TStringList; 
  begin
    res:=-1;  	
  	if (p[1]<>'') then
	begin
	  cmd:=cmdget(p);
      if test then writeln('cmd_do: '+cmd);
	  page3:=TStringList.create; 
	  res:=call_external_prog(LOG_NONE,cmd,page3);
	  if not (res=0) then 
	  begin
		if (UpdErrVerbose IN UpdFlags) then 
		begin 
		  LOG_Writeln(LOG_ERROR,'could not exec '+cmd);
		  if (page3.count>0) then LOG_ShowStringList(LOG_ERROR,page3); 
		end;
      end;							  
	  page3.free;
	end;
	cmd_do:=res;
  end;
    
begin
  DfltMaintDir:=	AppDataDir_c+'/'+ApplicationName+'/maint';	// /var/lib/<CompanyShortName>/<appname>/maint
  res:=-1; 
  test:=	(UpdDBG1 		IN UpdFlags); 
  test2:=	(UpdDBG2 		IN UpdFlags);  // test2:=true;
  noMD5Chk:=(UpdnoMD5Chk 	IN UpdFlags);
  
  flgs:=UpdFlags+[UpdNOP]; 
  FTPServer:=		RpiMaintCmd.ReadString('RPIMAINT','FTPSRV', '');	
  FTPUser:=  		RpiMaintCmd.ReadString('RPIMAINT','FTPUSR', '');		
  FTPPwd:=	 	 	RpiMaintCmd.ReadString('RPIMAINT','FTPPWD', '');	
  FTPlogf:=	 	 	RpiMaintCmd.ReadString('RPIMAINT','FTPLOG', '/tmp/rpimaint_ftp.log');
  FTPOpts:=	 	 	RpiMaintCmd.ReadString('RPIMAINT','FTPOPT', CURLFTPDefaults_c);
  usrpwd:=			FTPUser; if usrpwd='' then usrpwd:='anonymous';
  if FTPPwd<>'' then usrpwd:=usrpwd+':'+FTPPwd;
  if UpdNoFTPDefaults IN UpdFlags then FTPOpts:='';
  UplSrcFiles:=		RpiMaintCmd.ReadString('RPIMAINT','UPLSF', DfltMaintDir+'/supportfile_'+RPI_SNR+'.tgz');
  UplSrcPkgRem:=	RpiMaintCmd.ReadString('RPIMAINT','UPLREM',UplSrcFiles);
  
  
  UplDstDir:=		RpiMaintCmd.ReadString('RPIMAINT','UPLDD', '/'+ApplicationName+'/upload/'+RPI_SNR);
  Upllogf:=			RpiMaintCmd.ReadString('RPIMAINT','UPLLOG','/tmp/rpimaint_upload.log'); 
  
  DwnSrcDir:=		RpiMaintCmd.ReadString('RPIMAINT','DWNSD', '/'+ApplicationName);
  DwnSrcFiles:=		RpiMaintCmd.ReadString('RPIMAINT','DWNSF', ApplicationName+'.tgz');
  DwnDstDir:=		RpiMaintCmd.ReadString('RPIMAINT','DWNDD', DfltMaintDir);
  Dwnlogf:=			RpiMaintCmd.ReadString('RPIMAINT','DWNLOG','/tmp/rpimaint_dwnload.log'); 
  
  
  UpdPkgSrcDir:=	RpiMaintCmd.ReadString('RPIMAINT','UPDPSF', '/'+ApplicationName);
  UpdPkgSrcFile:=	RpiMaintCmd.ReadString('RPIMAINT','UPDPSF', '/'+ApplicationName+'/'+ApplicationName+'.tgz');
  UpdPkgDstDir:=	RpiMaintCmd.ReadString('RPIMAINT','UPDPDD', '/tmp');
  UpdPkgDstFile:=	RpiMaintCmd.ReadString('RPIMAINT','UPDPDF', ApplicationName+'.tgz');
  UpdPkgMaintDir:=	RpiMaintCmd.ReadString('RPIMAINT','UPDMDIR',DfltMaintDir);
  UpdPkglogf:=		RpiMaintCmd.ReadString('RPIMAINT','UPDPLOG','/tmp/rpimaint_updpkg.log');		    
  UpdPkgMD5FileOld:=   PrepFilePath(UpdPkgMaintDir+'/'+UpdPkgDstFile+'.md5');
  UpdPkgDstDirAndFile:=PrepFilePath(UpdPkgDstDir+  '/'+UpdPkgDstFile); 
  for cmd IN flgs do
  begin
    cmds:=GetEnumName(TypeInfo(t_rpimaintflags),ord(cmd));
    cmdsf:='PKGMGT['+StringReplace(cmds,'Upd','',[])+']:';
//  say(LOG_Info,'maint cmd/attrib['+cmds+']: last: '+Bool2Str(cmd=High(flgs)));
    res:=-1; parr_clean(p2); // clear para array  
	case cmd of
	  UpdExec:		begin // e.g. EXEC=ls -l /tmp 
					  say(LOG_Info,'enter maint step: '+cmds);
	      			  sh:=RpiMaintCmd.ReadString('RPIMAINT','EXEC','');
	      			  if (sh<>'') then
	      			  begin	
	      				for j:=1 to c_maxp do p2[j]:=Select_Item(sh,' ','',j);
//	      				if UpdSUDO IN UpdFlags then p2[1]:='sudo '+p2[1];  
	      				MSG_HUB(LOG_INFO,maintmsg,cmdsf);
	      				res:=cmd_do(p2); 
	      			  end else res:=0;
	      			end;
	  UpdUpld:		begin	
					  say(LOG_Info,'enter maint step: '+cmds);
	  				  if (FTPServer='') then
	  				  begin
	  				    say(LOG_ERROR,cmdsf+' no FTPServerInfo supplied, use RPI_MaintSetEnvFTP');  
	  				    break; 
	  				  end;
	  				  if (UplSrcFiles='') then
	  				  begin
	  				    say(LOG_ERROR,cmdsf+' no UpdPkgInfo supplied, use RPI_MaintSetEnvUPL');
	  				    break;
	  				  end;
//curl -u usr:pwd <curldefaults> -v -k --ssl -T "{file1,file2}" "ftp://host/upload/" > file.log 2> file.log.prog
					  p2[1]:='curl'; 	
//					  if UpdSUDO 		IN UpdFlags 	  then p2[1]:='sudo '+p2[1]; 					  
					  if usrpwd<>'' 					  then p2[2]:='-u '+usrpwd;
					  if UpdVerbose 	IN UpdFlags 	  then p2[2]:=p2[2]+' -v';
					  if UpdSSL     	IN UpdFlags 	  then p2[2]:=p2[2]+' '+CURLSSLDefaults_c;
					  if not (UpdNoCreateDir IN UpdFlags) then p2[2]:=p2[2]+' --ftp-create-dirs';
					  if FTPOpts<>'' then 	p2[2]:=p2[2]+' '+FTPOpts;
					  
					  p2[3]:='-T "{'+UplSrcFiles+'}"';
					  i64:=GetFilePackSize(UplSrcFiles);
					  if UpdProtoHTTP 	IN UpdFlags
					    then p2[4]:='"http://'+FTPServer+UplDstDir+'"' // if you have multiple files, do not forget trailing /
					    else p2[4]:='"ftp://'+ FTPServer+UplDstDir+'"';
					  parr_show('#1',p2);
//writeln('UplDstDir:',p2[4],' UplSrcFiles:',UplSrcFiles);
					  MSG_HUB(LOG_INFO,maintmsg,cmdsf+' '+FormatFileSize(i64));
					  if CURL_ProgressUpdateHook_ptr<>nil then MSG_HUB(LOG_INFO,maintmsg,cmdsf+' starting...');
					  CURL_SetPara(CurlThCtl,cmdsf,cmdget(p2),Upllogf,UplSrcFiles,Get_Dirs(UplSrcFiles),0,UpdFlags);					  
					  res:=CURL(CurlThCtl);
					  if (res<>0) then 
					  begin
						LOG_Writeln(LOG_ERROR,cmdsf+' Step#1 '+parr_gets(p2));
	      			 	MSG_HUB(	LOG_ERROR,maintmsg,'curl#1: '+CURL_ErrDesc(res));
	      			  end else say(	LOG_NOTICE,cmdsf+' '+Trimme('file '+UplSrcPkgRem+' successfully uploaded',4));
	      			end;  	      			
	  UpdDwnld:		begin // download file(s)
					  say(LOG_Info,'enter maint step: '+cmds);
	  				  if (FTPServer='') and (not (UpdProtoRAW IN UpdFlags)) then
	  				  begin 
	  				    say(LOG_ERROR,cmdsf+' no FTPSupportServer supplied, use RPI_MaintSetEnvFTP before');   
	  				    break;
	  				  end;
	  				  if (DwnSrcDir='') then
	  				  begin
	  				    say(LOG_ERROR,cmdsf+' no DwnSrcDir supplied, use RPI_MaintSetEnvDWN');
	  				    break;
	  				  end;
	  				  if (DwnSrcFiles='') then
	  				  begin
	  				    say(LOG_ERROR,cmdsf+' no DwnSrcFiles supplied, use RPI_MaintSetEnvDWN');
	  				    break;
	  				  end;
	  				  if (DwnDstDir='') then
	  				  begin
	  				    say(LOG_ERROR,cmdsf+' no DwnDstDir supplied, use RPI_MaintSetEnvDWN');
	  				    break;
	  				  end;
	  				  cdmod:='/#1';
	  				  if UpdProtoRAW 		IN UpdFlags then
	  				  begin
	  				  	sh:=DwnSrcDir+'/'+'{'+DwnSrcFiles+'}';
	  				  end
	  				  else
	  				  begin
	  				    if UpdProtoHTTP 	IN UpdFlags
					      then sh:='http://'+FTPServer+PrepFilePath(DwnSrcDir+'/')+'{'+DwnSrcFiles+'}'
					      else sh:='ftp://'+ FTPServer+PrepFilePath(DwnSrcDir+'/')+'{'+DwnSrcFiles+'}';
					  end;
					  if DwnDstDir='/dev/null' then cdmod:='';
//curl -u usr:pwd -v -k --ssl -o "./#1" "ftp://www.xyz.com/dir/{file1,file2,file3}" > "file.log" 2> "file.log.prog"
					  p2[1]:='curl'; 	
					  if usrpwd<>''						  	then p2[2]:='-u '+usrpwd;
//					  if UpdSUDO		IN UpdFlags 	  	then p2[1]:='sudo '+p2[1];  
					  if not (UpdNoRedoRequest IN UpdFlags) then p2[2]:=p2[2]+' -Lf'; 					  
					  if UpdVerbose 	IN UpdFlags 	  	then p2[2]:=p2[2]+' -v';
					  if UpdSSL     	IN UpdFlags 	  	then p2[2]:=p2[2]+' '+CURLSSLDefaults_c;
					  if not (UpdNoCreateDir IN UpdFlags) 	then p2[2]:=p2[2]+' --ftp-create-dirs';
					  
					  p2[2]:=p2[2]+' '+FTPOpts;
					  p2[3]:='-o'; 		p2[4]:='"'+PrepFilePath(DwnDstDir+cdmod)+'"'; 
					  p2[5]:='"'+sh+'"';p2[6]:='';					  					  
					  parr_show('#1',p2);
					  MSG_HUB(LOG_INFO,maintmsg,cmdsf);
					  if CURL_ProgressUpdateHook_ptr<>nil then MSG_HUB(LOG_INFO,maintmsg,cmdsf+' starting...');
					  CURL_SetPara(CurlThCtl,cmdsf,cmdget(p2),Dwnlogf,DwnSrcFiles,DwnDstDir,0,UpdFlags);	
					  res:=CURL(CurlThCtl);
					  if (res<>0) then
					  begin
					  	LOG_Writeln(LOG_ERROR,cmdsf+' Step#1 '+parr_gets(p2)); 
						MSG_HUB(	LOG_ERROR,maintmsg,'curl#1('+Num2Str(res,0)+') '+CURL_ErrDesc(res));
					  end else say(	LOG_Info,cmdsf+' successfully downloaded '+DwnSrcFiles);
					end;	
	 UpdPKGcopy:	begin // copy install package from source directory (e.g. USB-Stick)
	 				  say(LOG_Info,'enter maint step: '+cmds);
	 				  if (UpdPkgSrcDir='') or (UpdPkgDstFile='') then
	  				  begin 
	  				    say(LOG_ERROR,cmdsf+' no UpdPkgSrcFile supplied, use RPI_MaintSetEnvUPD before');   
	  				    break;
	  				  end; 
 					  
 					  p2[1]:='cp';
	  				  if UpdForce	IN UpdFlags then p2[1]:=p2[1]+' -f';
	  				  if UpdVerbose IN UpdFlags then p2[1]:=p2[1]+' -v';
	  				  if UpdUpdate	IN UpdFlags then p2[1]:=p2[1]+' -u';
//					  if UpdSUDO	IN UpdFlags	then p2[1]:='sudo '+p2[1]; 
					  p2[3]:=UpdPkgDstDir;

					  p2[2]:=PrepFilePath(UpdPkgSrcDir+'/'+UpdPkgDstFile);
					  if FileExists(p2[2]) then
					  begin
						parr_show('#1',p2);	cmd_do(p2);
						p2[2]:=p2[2]+'.md5';
						if FileExists(p2[2]) then
					  	begin
						  parr_show('#2',p2);	cmd_do(p2);
						  if FileExists(PrepFilePath(UpdPkgDstDir+'/'+UpdPkgDstFile)) and
						  	 FileExists(PrepFilePath(UpdPkgDstDir+'/'+UpdPkgDstFile)+'.md5')
							then res:=0
							else LOG_Writeln(LOG_ERROR,cmdsf+' Step#3 can not copy required install files '+UpdPkgDstFile); 
					  	end else LOG_Writeln(LOG_ERROR,cmdsf+' Step#2 file '+p2[2]+' does not exist'); 
					  end else LOG_Writeln(LOG_ERROR,cmdsf+' Step#1 file '+p2[2]+' does not exist'); 
					  if (res=0) then MSG_HUB(LOG_NOTICE,maintmsg,cmdsf+' USB-Stick')
					  			 else MSG_HUB(LOG_ERROR, maintmsg,cmdsf+' USB-Stick');
	 				end;			
	  UpdPKGGet:	begin // get a whole install package, check if download is needed
					  say(LOG_Info,'enter maint step: '+cmds);
	  				  if FTPServer='' then
	  				  begin 
	  				    say(LOG_ERROR,cmdsf+' no FTPSupportServer supplied, use RPI_MaintSetEnvFTP before');   
	  				    break;
	  				  end;
	  				  SAY(LOG_INFO,cmdsf+' download md5 file');
	  				  if UpdProtoHTTP 	IN UpdFlags
					    then sh:='http://'+FTPServer+UpdPkgSrcFile
					    else sh:='ftp://'+ FTPServer+UpdPkgSrcFile;				  
//curl -u usr:pwd <curldefaults> -v -k --ssl -o <dstfile>.md5 "ftp://ftp.host.com/<MaintUpdPkgSrcFile>.md5" > file.log 2> file.log.prog
					  p2[1]:='curl'; 	
					  if usrpwd<>'' 					  then p2[2]:='-u '+usrpwd;
//					  if UpdSUDO		IN UpdFlags 	  then p2[1]:='sudo '+p2[1];  
					  if UpdVerbose 	IN UpdFlags 	  then p2[2]:=p2[2]+' -v';
					  if UpdSSL     	IN UpdFlags 	  then p2[2]:=p2[2]+' '+CURLSSLDefaults_c;
					  if not (UpdNoCreateDir IN UpdFlags) then p2[2]:=p2[2]+' --ftp-create-dirs';
					  
					  p2[2]:=p2[2]+' '+FTPOpts;
					  p2[3]:='-o'; 			p2[4]:=UpdPkgDstDirAndFile+'.md5'; 
					  p2[5]:='"'+sh+'.md5"';p2[6]:='';
					  parr_show('#1',p2); 
					  MSG_HUB(LOG_INFO,maintmsg,cmdsf+' md5');
					  CURL_SetPara(CurlThCtl,cmdsf+' md5',cmdget(p2),FTPlogf,UpdPkgDstFile+'.md5',Get_Dirs(UpdPkgDstDirAndFile),0,UpdFlags);
					  res:=CURL(CurlThCtl);
					  if (res=0) then
					  begin
					    MD5_HashGETVersion(UpdPkgMD5FileOld,			versold,version_old_md5);
					    MD5_HashGETVersion(UpdPkgDstDirAndFile+'.md5',	version,version_new_md5);	
						say(LOG_NOTICE,cmdsf+' successfully downloaded '+UpdPkgDstFile+'.md5 ('+Num2Str(version_old_md5,0,3)+' '+Num2Str(version_new_md5,0,3)+')');					
						if noMD5Chk or (not MD5Chk(LOG_INFO,LOG_WARNING,UpdPkgDstDirAndFile+'.md5',UpdPkgMD5FileOld)) then
						begin // get big file, there is a different package available
						  SAY(LOG_INFO,cmdsf+' download tar ball');
						  p2[4]:=UpdPkgDstDirAndFile; p2[5]:='"'+sh+'"';
						  parr_show('#2',p2);
						  MSG_HUB(LOG_INFO,maintmsg,cmdsf+' '+version);
						  CURL_SetPara(CurlThCtl,cmdsf,cmdget(p2),FTPlogf,UpdPkgDstFile,Get_Dirs(UpdPkgDstDirAndFile),0,UpdFlags+[UpdLogAppend]);
						  res:=CURL(CurlThCtl);
						  if (res=0) then
						  begin
						    i64:=GetFilePackSize(UpdPkgDstFile);
						    MSG_HUB(LOG_NOTICE,maintmsg,cmdsf+' '+FormatFileSize(i64)+' '+version);
							say(LOG_NOTICE,cmdsf+' successfully downloaded '+FormatFileSize(i64)+' '+version+' '+UpdPkgDstFile);
							parr_clean(p2); 
							p2[1]:='md5sum'; p2[2]:=UpdPkgDstDirAndFile; 
//							if UpdSUDO 	  IN UpdFlags then	p2[1]:='sudo '+p2[1];  
							p2[3]:='>'; p2[4]:=UpdPkgDstDirAndFile+'.md5.2'; 
							parr_show('#3',p2);	
							if (cmd_do(p2)=0) then
							begin
							  if MD5Chk(LOG_INFO,LOG_ERROR,UpdPkgDstDirAndFile+'.md5',UpdPkgDstDirAndFile+'.md5.2') then 
							  begin
								res:=0; say(LOG_NOTICE,cmdsf+' valid md5 of '+UpdPkgDstFile);
								MSG_HUB(LOG_NOTICE,maintmsg,cmdsf+' chk md5');
							  end
							  else
							  begin
								LOG_Writeln(LOG_ERROR,cmdsf+' Step#4 '+parr_gets(p2)); 
								MSG_HUB(LOG_ERROR,maintmsg,cmdsf+' chk md5 bad xfr');
								parr_clean(p2); 
								p2[1]:='rm'; 				p2[2]:='-f'; 
//								if UpdSUDO IN UpdFlags then	p2[1]:='sudo '+p2[1];  
								p2[3]:=UpdPkgDstDirAndFile; 
								parr_show('#4',p2);
								LOG_Writeln(LOG_ERROR,cmdsf+' invalid md5 of '+UpdPkgDstFile+' '+parr_gets(p2)+' bad xfr');
								cmd_do(p2); // remove unvalid package
							  end;								  
							end else begin LOG_Writeln(LOG_ERROR,cmdsf+' Step#3 '+parr_gets(p2)); end;
						  end 
						  else 
						  begin
							LOG_Writeln(LOG_ERROR,cmdsf+' Step#2 '+parr_gets(p2)); 
							MSG_HUB(	LOG_ERROR,maintmsg,'curl#2('+Num2Str(res,0)+') '+CURL_ErrDesc(res));
						  end;
						end
						else 
						begin
						  res:=0; 
						  say(LOG_Info,cmdsf+' valid md5 of '+UpdPkgDstFile+', file was already successfully transferred');
						end;
					  end 
					  else 
					  begin
						LOG_Writeln(LOG_ERROR,cmdsf+' Step#1 '+parr_gets(p2)); 
						MSG_HUB(	LOG_ERROR,maintmsg,'curl#1 '+CURL_ErrDesc(res));
					  end;
					end;
	  UpdPKGInstV,			
	  UpdPKGInst:	begin
					  say(LOG_Info,'enter maint step: '+cmds);
	  	  			  if (UpdPkgDstFile='') then
	  				  begin 
	  				    say(LOG_ERROR,cmdsf+' no UpdPkgInfo supplied, use RPI_MaintSetEnvUPD');  
	  				    break;
	  				  end;
	  				  MD5_HashGETVersion(UpdPkgDstDirAndFile+'.md5',version,version_new_md5);
					  if noMD5Chk or (not MD5Chk(LOG_INFO,LOG_WARNING,UpdPkgDstDirAndFile+'.md5',UpdPkgMD5FileOld)) then
					  begin // newer pkg should be available, try to install it
						say(LOG_INFO,cmdsf+' deploying newer package '+UpdPkgDstFile);
						if FileExists(UpdPkgDstDirAndFile) then
						begin						  
						  p2[1]:='tar'; 					p2[2]:='-xvzf';
//						  if UpdSUDO 	  IN UpdFlags then	p2[1]:='sudo '+p2[1];  
						  p2[3]:=UpdPkgDstDirAndFile;		p2[4]:='-C'; 
						  p2[5]:=UpdPkgDstDir;  			p2[6]:='';
						  if UpdLogAppend IN UpdFlags then	p2[7]:='>>' 	else p2[7]:='>';  				
						  p2[8]:=UpdPkglogf; 				p2[9]:='2>&1'; 
						  parr_show('#1',p2);
						  MSG_HUB(LOG_INFO,maintmsg,cmdsf+' UnPck');
						  if (cmd_do(p2)=0) then 
						  begin
							if UpdPKGInstV IN UpdFlags then
							begin
//							  LOG_Writeln(LOG_ERROR,cmdsf+' UpdPKGInstVers currently not implemented'); 
							  r:=0;
							  filnam:=PrepFilePath(UpdPkgDstDir+'/version.txt');
							  if FileExists(filnam) then
							  begin
							    tl:=TStringList.create;
								if TextFile2StringList(filnam,tl,sh) then
								begin
								  if (tl.count>0) then 
								  begin
								    sh:=FilterChar(tl[0],'0123456789.');
									if Str2Num(sh,r) then
									begin
// 												    maint[UpdPKGInstal]: (/tmp/version.txt 0.92) V:0.920
									  SAY(LOG_Info,cmdsf+' ('+filnam+' '+tl[0]+') V:'+Num2Str(r,0,3)+
										' Vmin:'+Num2Str(RPI_MaintMinVersion,0,3)+
										' Vmax:'+Num2Str(RPI_MaintMaxVersion,0,3));
									  if (RPI_MaintMinVersion>0) and (r<RPI_MaintMinVersion) then
									  begin
									    LOG_Writeln(LOG_ERROR,cmdsf+' version '+Num2Str(r,0,3)+' < required minimum version '+Num2Str(RPI_MaintMinVersion,0,3)+' stop installation');
										break;
									  end;
									  if (RPI_MaintMaxVersion>0) and (r>RPI_MaintMaxVersion) then
									  begin
									  	LOG_Writeln(LOG_ERROR,cmdsf+' version '+Num2Str(r,0,3)+' > required maximum version '+Num2Str(RPI_MaintMaxVersion,0,3)+' stop installation');
										break;
									  end;
									end else LOG_Writeln(LOG_ERROR,	cmdsf+' no valid version supplied ('+sh+'), installing package');
								  end else LOG_Writeln(LOG_ERROR,	cmdsf+' version file has no content, installing package');	
								end else LOG_Writeln(LOG_ERROR,		cmdsf+' version file not supplied, installing package');								
								tl.free;
							  end;
							end;  // UpdPKGInstVers
							parr_clean(p2); 
							filnam:=PrepFilePath(UpdPkgDstDir+'/install.sh');
							p2[1]:='chmod'; 				p2[2]:='+x'; 
//							if UpdSUDO 	  IN UpdFlags then	p2[1]:='sudo '+p2[1];  
							p2[3]:=filnam;
							p2[7]:='>>'; 	p2[8]:=UpdPkglogf;	p2[9]:='2>&1';
							parr_show('#2',p2);
							if (cmd_do(p2)=0) then 
							begin			
							  parr_clean(p2);  
							  p2[1]:=filnam+' "'+rpi_snr+'" "'+UpdPkgMaintDir+'" "'+UpdPkglogf+'"';   //	execute install.sh
//							  if UpdSUDO IN UpdFlags then		p2[1]:='sudo '+p2[1];  
							  p2[7]:='>>'; 	p2[8]:=UpdPkglogf;	p2[9]:='2>&1';
							  parr_show('#3',p2);
							  if (cmd_do(p2)=0) then 
							  begin	
							    res:=0;
							    parr_clean(p2);  // cp -f /tmp/rfm.tgz.md5 <UpdPkgMaintDir>/rfm.tgz.md5
							    p2[1]:='cp -f '+UpdPkgDstDirAndFile+'.md5 '+UpdPkgMD5FileOld;
//								if UpdSUDO IN UpdFlags then	p2[1]:='sudo '+p2[1];  
							    cmd_do(p2);
							    if res=0 then 
							    begin
							      say(LOG_NOTICE,cmdsf+' package '+UpdPkgDstFile+' successfully deployed');
							      MSG_HUB(LOG_NOTICE,maintmsg,cmdsf+' Inst');
							    end else LOG_Writeln(LOG_ERROR,cmdsf+' Step#5 '+p2[1]); 
							  end else LOG_Writeln(LOG_ERROR,cmdsf+' Step#4 '+p2[1]); 
							end else LOG_Writeln(LOG_ERROR,cmdsf+' Step#3 '+parr_gets(p2)); 
						  end else LOG_Writeln(LOG_ERROR,cmdsf+' Step#2 '+parr_gets(p2)); 
						end else LOG_Writeln(LOG_ERROR,cmdsf+' Step#1, Package not available: '+UpdPkgDstFile);							  
					  end
					  else 
					  begin
					    res:=0; 
					    say(LOG_INFO,cmdsf+' Packages are identical, no update needed');
					    MSG_HUB(LOG_INFO,maintmsg,cmdsf+' already inst');
					  end;					
					end;
		  else		res:=0;	// do nothing, just attribs no commands
	    end; // case
	if res<>0 then break;
  end; // for
  RPI_Maint:=res;
end;

function  TTY_console:string;
var sh:string;
begin
  call_external_prog(LOG_NONE,'cat /sys/class/tty/console/active',sh);
  sh:=Trimme(sh,4);
//writeln('TTY_console:',sh,':');
  TTY_console:=sh;
end;
 
function  TTY_setterm(lvl:t_ErrorLevel; ttydev,ttyopts:string):integer; 	
// setterm --cursor off --clear all > /dev/tty1
var res:integer; sh:string;
begin
  res:=-1;
  if FileExists(ttydev) and (ttyopts<>'') then
  begin
    sh:='setterm '+ttyopts+' > '+ttydev;
//	SAY(lvl,sh);
    res:=call_external_prog(LOG_NONE,sh,sh);
  end else LOG_Writeln(LOG_ERROR,'TTY_setterm: device does not exist: '+ttydev);
  TTY_setterm:=res;
end; 
 
function  TTY_sttySpeed(lvl:t_ErrorLevel; ttyandspeed:string):integer; 	// e.g. /dev/ttyAMA0@9600 -cstopb -parodd
var res:integer; _speed,_par,_tty,sh:string; baudr:longword;
begin
  res:=-1;
  _par:=  Select_RightItems	(ttyandspeed,' ','',2);	// -cstopb -parodd
  _tty:=  Select_Item		(ttyandspeed,' ','',1);	// /dev/ttyAMA0@9600
  _speed:=Select_Item		(_tty,'@','',2);		// 9600
  _tty:=  Select_Item		(_tty,'@','',1);		// /dev/ttyAMA0
  if not Str2Num(_speed,baudr) then baudr:=9600;
  if FileExists(_tty) then
  begin
    sh:=Trimme('stty -F '+_tty+' '+Num2Str(baudr,0)+' '+_par,3);
//	SAY(lvl,sh);
    res:=call_external_prog(LOG_NONE,sh,sh);
  end else LOG_Writeln(LOG_ERROR,'TTY_sttySpeed: device does not exist: '+_tty);
  TTY_sttySpeed:=res;
end;

procedure ERR_MGMT_UPD(errhdl:integer; cmdcode,datalgt:byte; modus:boolean);
begin
  if (errhdl<>NO_ERRHNDL) and (Length(ERR_MGMT)>0) and (errhdl<Length(ERR_MGMT)) then
  begin
    with ERR_MGMT[errhdl] do
	begin
	  if modus then
	  begin // ok part
	    TSokOld:=TSok; TSok:=now; 
		if AutoReset_ms>0 then
		begin
		  if (MilliSecondsBetween(TSok,TSerr)>=AutoReset_ms) then
		    begin RDerr:=0; WRerr:=0; CMDerr:=0; end;
		end;
	  end
	  else
	  begin // error part
	    TSerrOld:=TSerr; TSerr:=now;
	    case cmdcode of
	      _IOC_READ:  inc(RDerr);
		  _IOC_WRITE: inc(WRerr);
		  else		  inc(CMDerr);
	    end; // case
	  end;
	end; // with
  end;
end;

function  ERR_MGMT_GetErrCnt(errhdl:integer):longword;
var err:longword;
begin
  err:=0;
  if (Length(ERR_MGMT)>0) and (errhdl>=0) and (errhdl<Length(ERR_MGMT)) then
    with ERR_MGMT[errhdl] do err:=RDerr+WRerr+CMDerr;
  ERR_MGMT_GetErrCnt:=err;
end;
	
function  ERR_MGMT_STAT(errhdl:integer):boolean;
var ok:boolean;
begin
  if (Length(ERR_MGMT)>0) and (errhdl<Length(ERR_MGMT)) then
  begin
    with ERR_MGMT[errhdl] do begin ok:=((RDerr+WRerr+CMDerr)<=MAXerr); end;
  end else ok:=true;
  ERR_MGMT_STAT:=ok;
end;

function  ERR_NEW_HNDL(adr:word; descr:string; maxerrs,AutoResetMsec:longword):integer; 
var h:integer;
begin 
  SetLength(ERR_MGMT,(Length(ERR_MGMT)+1)); 
  h:=(Length(ERR_MGMT)-1); 
  if h>=0 then 
  begin
    with ERR_MGMT[h] do
	begin
	  addr:=adr; desc:=descr; 
	  RDErr:=0; WRErr:=0; CMDerr:=0; MaxErr:=maxerrs;
	  TSok:=now; TSokOld:=TSok; TSerr:=TSok; TSerrOld:=TSerr;
	  AutoReset_ms:=AutoResetMsec;	// 0:off
	end; // with
  end;
  ERR_NEW_HNDL:=h;
end;

procedure ERR_Report(errhdl:integer);
var _lvl:T_ErrorLevel;
begin
  if (Length(ERR_MGMT)>0) and (errhdl<Length(ERR_MGMT)) then
  begin
    with ERR_MGMT[errhdl] do 
    begin 
	  if ERR_MGMT_STAT(errhdl) then _lvl:=LOG_NOTICE else _lvl:=LOG_ERROR;
	  LOG_Writeln(_lvl,	'ERR_MGMT[0x'+Hex(addr,4)+']: '+desc+
						' ERR RD:'+Num2Str(RDerr,0)+
						' WR:'+Num2Str(WRerr,0)+
						' CMD:'+Num2Str(CMDerr,0)+
						' AutoReset:'+Num2Str(AutoReset_ms,0)+'ms');
    end; // with
  end;
end;

procedure ERR_End(hndl:integer); 
var i:integer;
begin 
  for i:= 1 to Length(ERR_MGMT) do ERR_Report(i-1);
  SetLength(ERR_MGMT,0); 
end;

{$IFDEF UNIX}  
function  Term_ptmx(var termio:Terminal_device_t; link:string; menablemask,mdisablemask:longint):boolean;
// opens pseudo terminal.
// returns master and slave filedescriptor, and slavename for usage. link, links slavename to link
// masks: Term_ptmx(x,x,x,x, 0,ECHO) -> disables TerminalECHO // 0=noEnableAnything,disable ECHO
const ptmx_c='/dev/ptmx';
var snp:pchar; linkflag:boolean; tl:TStringList; newsettings:termios; sh:string;
begin 
  with termio do
  begin
    slavepath:=''; masterpath:=ptmx_c; linkpath:=link; fdslave:=-1; rlgt:=-1; ridx:=0; linkflag:=true; 
    fdmaster := fpopen (ptmx_c, Open_RDWR or O_NONBLOCK);
    if fdmaster>=0 then
    begin
      if grantpt(fdmaster)>=0 then
      begin
	    if unlockpt(fdmaster)>=0 then
        begin
	      snp:=ptsname(fdmaster);
          if snp<>nil then
          begin
		    slavepath:=snp;
		    fdslave:=fpopen(snp, Open_RDWR or O_NONBLOCK);
            if fdslave>=0 then 
		    begin
		      if FileExists(slavepath) then
			  begin
		        if link<>'' then
			    begin
			      tl:=TStringList.create;
			      if FileExists(link) then 
				  begin 
				    LOG_WRITELN(LOG_Warning,'ptmx, link exits: '+link+' (unlink '+link+')');
				    call_external_prog(LOG_NONE,'unlink '+link+'; ls -l '+link,sh);
					LOG_ShowStringList(LOG_WARNING,tl);
			        sleep(500);
				  end;
				  if (not FileExists(link)) then
			      begin
			        call_external_prog(LOG_NONE,'ln -s '+slavepath+' '+link+'; ls -l '+link,sh);
//LOG_ShowStringList(LOG_WARNING,tl);
					sleep(500);
				    linkflag:=FileExists(link);
				    if not linkflag then 
					begin
					  LOG_WRITELN(LOG_ERROR,'ptmx: cannot create link '+link+' (ln -s '+slavepath+' '+link+')');
					  LOG_ShowStringList(LOG_ERROR,tl);
					end;
//	                if master_termioflags_AND_mask<>0 then
				    begin
	                  tcgetattr(fdmaster, @newsettings);  			// pmtx(x,x,x,x, 0,ECHO) -> disables TerminalECHO
	                  newsettings.c_lflag:=(newsettings.c_lflag or menablemask) and (not mdisablemask); // &= ~(ECHO | ICANON | IEXTEN | ISIG);
	                  tcsetattr(fdmaster, TCSANOW, @newsettings); 	// was TCSADRAIN
                    end;				  
 		          end else LOG_WRITELN(LOG_ERROR,'ptmx: link already exists: '+link);
			      tl.free;
			    end;
			  end else LOG_WRITELN(LOG_ERROR,'ptmx: not created '+slavepath);
		    end else LOG_WRITELN(LOG_ERROR,'ptmx: cannot open '+slavepath);
          end else LOG_WRITELN(LOG_ERROR,'ptmx: cannot get slavepath');
	    end else LOG_WRITELN(LOG_ERROR,'ptmx: cannot unlockpt');
	  end else LOG_WRITELN(LOG_ERROR,'ptmx: cannot grantpt');
    end else LOG_WRITELN(LOG_ERROR,'ptmx: cannot open '+ptmx_c);
//  writeln('ptmx fd: ',fdmaster,' ',fdslave,' ',((fdmaster>=0) and (fdslave>=0) and (slavepath<>'') and linkflag),' ',slavename);
    Term_ptmx:=((fdmaster>=0) and (fdslave>=0) and (slavepath<>'') and linkflag);
  end; // with
end;

function  TermIO_Read(var term:Terminal_device_t; rawmode:boolean):string;
var i:longint; str:string; ende:boolean;
begin
  str:=''; ende:=false;
  with term do
  begin
    if (fdmaster>=0) then
    begin
      if ridx<=0 then begin rlgt:=fpread(fdmaster,@si,Terminal_MaxBuf); ridx:=0; end;
	  if rawmode then
	  begin
	    for i := 1 to rlgt do str:=str+si[i];
		ridx:=0;
	  end
	  else
	  begin
		while (ridx<rlgt) and (not ende) do
	    begin
		  inc(ridx);
	      if (si[ridx]=LF) then ende:=true
                           else if (si[ridx]<>CR) then str:=str+si[ridx]; 
	    end;
		if ridx>=rlgt then ridx:=0;
	  end;
	end;
  end; // with
  TermIO_Read:=str;
end;

procedure TermIO_Write(var term:Terminal_device_t; str:string);
begin
  with term do
  begin
    if (fdmaster>=0) then
    begin
      if fpwrite(fdmaster,str[1],length(str))<0 then 
      	LOG_Writeln(LOG_ERROR,'TermIO_Write: '+LNX_ErrDesc(fpgeterrno));
	end;
  end;
end;

procedure DoActionOnReceivedInput(s:string); 
// just for Demo. Process can react on InputCommands, written to our device /dev/testbidir
begin writeln('Received: ',s); end;

procedure Test_BiDirectionDevice_in_UserSpace; // write and read from /dev/testbidir
const maxloops=100;
var termio:Terminal_device_t; loop:longint; str:string;
begin
  loop:=1;
  with termio do
  begin
    writeln('Start of Test_BiDirectionDevice_in_UserSpace, do ',maxloops:0,' loops (user root)');
    if Term_ptmx(termio,'/dev/testbidir',0,ECHO) then
    begin
	  fpclose(fdslave);
	  writeln('Screen1: pls. open 2 additional terminal sessions (e.g. with putty to your pi user:root)');
	  writeln('filedescriptor master: ',fdmaster,'   fdslave: ',fdslave);
	  writeln('masterpath: ',masterpath);
	  writeln('slavepath:  ',slavepath);
	  writeln('linkpath:   ',linkpath,' linked to ',slavepath);
	  writeln('do a cat ',linkpath,' on screen2, to see data which was written to master device');
	  writeln('do a echo xxxxx >> ',linkpath,' on screen3 to pass data which the master can read');
	  sleep(5000); 
	  writeln('Start to write Hello#<nr> to master device');
      repeat   
	    str:=TermIO_Read(termio,false); 					// async read from master device
		if str<>'' then DoActionOnReceivedInput(str);		// process input data, if something was red
	    TermIO_Write(termio,'Hello#'+Num2Str(loop,0)+LF);	// write to  master device
        sleep(1000); inc(loop);
      until loop>maxloops;
	  writeln('closing '+linkpath);
	  fpclose(fdmaster);
	  writeln('End of Test_BiDirectionDevice_in_UserSpace (you should get an Input/output error on screen2 now)');
    end else writeln('ptmx init failed');
  end;
end;
{$ENDIF}
	  
function  TempLVLset(Temp,Tmax:real):t_ERRORLevel;
var lvl:t_ERRORLevel;
begin
  lvl:=LOG_NONE;
  if not (IsNaN(Temp) or IsNaN(Tmax)) then
  begin
	lvl:=LOG_INFO;	
	if (Temp<=Tmax*RPI_CTempCool_c)	then lvl:=LOG_NOTICE;
	if (Temp>=Tmax*RPI_CTempWarn_c)	then lvl:=LOG_WARNING;
	if (Temp>=Tmax*RPI_CTempHot_c)	then lvl:=LOG_ERROR;
	if (Temp>=Tmax)					then lvl:=LOG_URGENT;
  end;
  TempLVLset:=lvl;
end;

function  RPI_Temp(logmsg:boolean):t_ERRORLevel;
var _lvl:t_ERRORLevel; n:longint; tag:longword; sh,_unit:string; p:array[0..1] of longword;
begin
  with RPI_Temps do
  begin
	_lvl:=LOG_NONE; _unit:=TempUnit[1]; TempIdx:=1; TempInfo:='';
  	if RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_MAX_TEMPERATURE,addr(p),sizeof(p))>0
	  then TempMax:=p[1]/1000 else TempMax:=RPI_TempAlarmCelsius_c; 
  
	for n:= 1 to 2 do
  	begin
	  Temp[n]:=NaN; TempLvl[n]:=LOG_NONE; 
	  tag:=TAG_GET_TEMPERATURE; sh:='CPU';
	  case n of
		2: 	 begin sh:='GPU'; tag:=TAG_GET_TEMPERATURE; end; // missing fw tag for GPU temp
	  end; // case
      if RPI_FW_property(TAG_STATUS_REQUEST,tag,addr(p),sizeof(p))>0 then
      begin
		Temp[n]:=p[1]/1000;
      	TempLvl[n]:=TempLVLset(Temp[n],TempMax);
      	if TempLvl[n]>=_lvl then _lvl:=TempLvl[n];
	  	TempInfo:=TempInfo+sh+':'+Num2Str((Temp[n]),0,1)+_unit+';';
	  	if logmsg and (_lvl>=LOG_WARNING) then
		  SAY(TempLvl[n],'RPI_TempAlarm['+sh+']: '+Num2Str(Temp[n],0,1)+_unit+' (AlarmTemp: '+Num2Str(TempMax*RPI_CTempHot_c,0,1)+_unit+')');
      end else TempInfo:=TempInfo+sh+':--.-'+_unit+';';
	end; // for 
  
	TempInfo:=TempInfo+'COOL:'+ Num2Str(TempMax*RPI_CTempCool_c,	0,1)+_unit+';';
	TempInfo:=TempInfo+'WARN:'+ Num2Str(TempMax*RPI_CTempWarn_c,	0,1)+_unit+';';
 	TempInfo:=TempInfo+'HOT:'+  Num2Str(TempMax*RPI_CTempHot_c,		0,1)+_unit+';';
	TempInfo:=TempInfo+'ALARM:'+Num2Str(TempMax,					0,1)+_unit;
//	TempInfo: CPU:41.8'C;GPU:--.-'C;COOL:40.0'C;WARN:65.0'C;HOT:75.0'C;ALARM:85.0'C	// temps in celsius
  end; // with
  RPI_Temp:=_lvl;
end;

function  RPI_Volt:string;	// core:1.2000V;sdram_c:1.2000V;sdram_i:1.2000V;sdram_p:1.2250V
const volt_c='for src in core sdram_c sdram_i sdram_p ; do echo "$src:$(vcgencmd measure_volts $src|awk -F ''='' ''{print $2}'')" ; done';
var   _ts:TStringlist; i:longint; sh:string; 
begin
  _ts:=TStringList.create; sh:='';
  call_external_prog(LOG_NONE,volt_c,_ts); 
  for i:= 1 to _ts.count do
  begin
	sh:=sh+_ts[i-1];
    if i<_ts.count then sh:=sh+';';
  end;
  _ts.free;
  RPI_Volt:=sh;
end;

function  RPI_FREQs:string;	// arm:600000000;core:250000000;h264:250000000;isp:250000000;...
const frq_c= 'for src in arm core h264 isp v3d uart pwm emmc pixel vec hdmi dpi ; do echo "$src:$(vcgencmd measure_clock $src|awk -F ''='' ''{print $2}'')" ; done';
var   _ts:TStringlist; i:longint; sh:string; 
begin
  _ts:=TStringList.create; sh:='';
  call_external_prog(LOG_NONE,frq_c,_ts); 
  for i:= 1 to _ts.count do
  begin
	sh:=sh+_ts[i-1];
    if i<_ts.count then sh:=sh+';';
  end;
  _ts.free;
  RPI_FREQs:=sh;
end;

function  RPI_GPU_MEM_BASE:longword; begin RPI_GPU_MEM_BASE:=GPU_MEM_BASE; end;

function  RPI_INFO_Split(info:string; var labl,valu:string):boolean;
begin // in: CPU:41.8'C out: labl:CPU value:41.8'C
  labl:=Trimme(Select_Item(info,':','',1),3);
  valu:=Trimme(Select_Item(info,':','',2),3);
  RPI_INFO_Split:=((labl<>'') and (valu<>''));
end;

procedure Get_CPU_INFO_Init;   
// https://en.wikipedia.org/wiki/Raspberry_Pi
const proc1_c='cat /proc/cpuinfo'; proc2_c='cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo'; 
	  proc3_c='cat /etc/debian_version';
var ts:TStringlist; sh:string; anz:longint; lw:longword; 
  function cpuinfo_unix(infoline:string; var cnt:longint):string;
  var s:string; i:integer;
  begin
    s:=''; i:=1; cnt:=0;
    while (i<=ts.count) do 
    begin 
      if Pos(Upper(infoline),Upper(ts[i-1]))=1 then 
      begin 
    	s:=ts[i-1]; inc(cnt); // i:=ts.count+1; 
      end; 
      inc(i); 
    end;
	cpuinfo_unix:=copy(s,Pos(':',s)+2,Length(s));
  end;
  function getvcgencmd(opt:string; var val:real):boolean;
  var _ok:boolean;
  begin
    ts.clear; _ok:=false;
    if (call_external_prog(LOG_NONE,'vcgencmd measure_clock '+opt,sh)=0) then 
    begin
      sh:=RM_CRLF(sh);
	  if sh<>'' then if Str2Num(copy(sh,Pos(')=',sh)+2,Length(sh)),val) then _ok:=true;
	end;
	getvcgencmd:=_ok;
  end;
  function  RPI_SetInfo(cpurevs,desc,manuf:string; cpurev:real; I2Cbusnr,gpioidx,slednr,pincnt,cores:byte;memsizMB:word):string;
//          RPI_SetInfo('0010', 'B', 'Sony UK',    1.0,         0,       2,      47,    40,    1,         512);
  begin
    connector_pin_count:=pincnt; cpu_rev_num:=cpurev; I2C_busnum:=I2Cbusnr; 
    GPIO_map_idx:=gpioidx; 	status_led_GPIO:=slednr; 
    RPI_SetInfo:=	'rev'+Num2Str(cpurev,0,1)+';'+
					Num2Str(memsizMB,0)+'MB;'+
					desc+';'+cpu_hw+';'+cpurevs+';'+
	                Num2Str(connector_pin_count,0)+';'+
	                Num2Str(cores,0)+';'+
	                cpu_machine+';'+
	                manuf;		//	  rev1.0;512MB;B;BCM2709;0010;40;1;Sony UK
  end;
  function  AnalyzeRevCode(cpurevs:string):string;
// https://www.raspberrypi.org/documentation/hardware/raspberrypi/revision-codes/README.md
  var F,M,C,P,R:byte; sh:string;
  begin
	sh:='';
	if Str2Num('0x'+cpurevs,lw) then
	begin
	  F:=((lw and $00800000) shr 23);	// New flag		1Bit
	  if (F=0) then
	  begin // 0: old style
	  	case (lw and $ff) of
		  $00: sh:=RPI_SetInfo(cpurevs,'B',  '',		1.0, 0, 1, 16, 26, 1, 256);
		  $01: sh:=RPI_SetInfo(cpurevs,'B',  '',		1.0, 0, 1, 16, 26, 1, 256);
		  $02: sh:=RPI_SetInfo(cpurevs,'B',  'Egoman',	1.0, 0, 1, 16, 26, 1, 256);
		  $03: sh:=RPI_SetInfo(cpurevs,'B',  'Egoman',	1.0, 0, 1, 16, 26, 1, 256);
	      $04: sh:=RPI_SetInfo(cpurevs,'B',  'Sony UK',	2.0, 1, 2, 16, 26, 1, 256);
	      $05: sh:=RPI_SetInfo(cpurevs,'B',  'Qisda',	2.0, 1, 2, 16, 26, 1, 256);
	      $06: sh:=RPI_SetInfo(cpurevs,'B',  'Egoman',	2.0, 1, 2, 16, 26, 1, 256);
		  $07: sh:=RPI_SetInfo(cpurevs,'A',  'Egoman',	2.0, 1, 2, 16, 26, 1, 256);
		  $08: sh:=RPI_SetInfo(cpurevs,'A',  'Sony UK',	2.0, 1, 2, 16, 26, 1, 256);
		  $09: sh:=RPI_SetInfo(cpurevs,'A',  'Qisda',	2.0, 1, 2, 16, 26, 1, 256);
		  $0d: sh:=RPI_SetInfo(cpurevs,'A',  'Egoman',	2.0, 1, 2, 16, 26, 1, 256);
		  $0e: sh:=RPI_SetInfo(cpurevs,'A',  'Sony UK',	2.0, 1, 2, 16, 26, 1, 256);
		  $0f: sh:=RPI_SetInfo(cpurevs,'B',  'Egoman',	2.0, 1, 2, 16, 26, 1, 512);
		  $10: sh:=RPI_SetInfo(cpurevs,'B+', 'Sony UK',	1.0, 0, 2, 47, 40, 1, 512);
		  $11: sh:=RPI_SetInfo(cpurevs,'CM1','Sony UK',	1.1, 0, 2, 47,  0, 1, 512); 
		  $12: sh:=RPI_SetInfo(cpurevs,'A+', 'Sony UK',	1.1, 0, 2, 47, 40, 1, 256);
		  $13: sh:=RPI_SetInfo(cpurevs,'B+', 'Embest',	1.2, 0, 2, 47, 40, 1, 512);
		  $14: sh:=RPI_SetInfo(cpurevs,'CM1','Embest',	1.1, 0, 2, 47,  0, 1, 512); 
		  $15: sh:=RPI_SetInfo(cpurevs,'A+', 'Embest',	1.1, 0, 2, 47, 40, 1, 256);
		  else LOG_Writeln(LOG_ERROR,'Get_CPU_INFO_Init: (0x'+Hex(lw,8)+') unknown rev:'+cpurevs+': RPI not supported');
		end; // case
	  end
	  else
	  begin // 1: new style flag
	  	connector_pin_count:=40;	GPIO_map_idx:=2;	cpu_hw:='';
		status_led_GPIO:=47;		I2C_busnum:=1; 
// 		uuuuuuuuFMMMCCCCPPPPTTTTTTTTRRRR
		R:=			((lw and $0000000f));			// Revision		4Bit
		RPI_bType:=	((lw and $00000ff0) shr  4);	// Type			8Bit
		P:=			((lw and $0000f000) shr 12);	// Processor	4Bit
		C:=			((lw and $000f0000) shr 16);	// Manufacturer	4Bit
		M:=			((lw and $00700000) shr 20);	// Memory size	3Bit
//		u:=			((lw and $ff000000) shr 24);	// Unused		8Bit
//		writeln(cpurevs,' F:',F,' R:',R,' T:',T,' P:',P,' C:',C,' M:',M);
// a020d3 F:1 R:3 T:13 P:2 C:0 M:2
// rev1.3;1GB;3B+;BCM2837;a020d3;40;4;Sony UK
		sh:=sh+'rev1.'+Num2Str(R,0)+';';
		case M of // Memory size
		    0: sh:=sh+'256MB';
		    1: sh:=sh+'512MB';
		    2: sh:=sh+'1GB';
		  else sh:=sh+'0x'+Hex(M,2);
		end; // case 
		sh:=sh+';';
		case RPI_bType of // Type
		    0: sh:=sh+'A';
		    1: sh:=sh+'B';
		    2: sh:=sh+'A+';
		    3: sh:=sh+'B+';
		    4: sh:=sh+'2B';
		    5: sh:=sh+'Alpha (early prototype)';
		    6: sh:=sh+'CM1';
		    8: sh:=sh+'3B';
		    9: sh:=sh+'Zero';
		  $0a: sh:=sh+'CM3';
		  $0c: sh:=sh+'Zero W';
		  $0d: sh:=sh+'3B+';
		  $0e: sh:=sh+'3A+';
		  else sh:=sh+'0x'+Hex(RPI_bType,2);
		end; // case					
		sh:=sh+';';
		case P of // Processor
		    0: cpu_hw:='BCM2835';
		    1: cpu_hw:='BCM2836';
		    2: cpu_hw:='BCM2837';
		  else cpu_hw:=cpu_hw+'0x'+Hex(P,2);
		end; // case
		sh:=sh+cpu_hw+';'+cpurevs+';'+Num2Str(connector_pin_count,0)+';'+Num2Str(cpu_cores,0)+';'+cpu_machine+';';
		case C of // Manufacturer
		    0: sh:=sh+'Sony UK';
		    1: sh:=sh+'Egoman';
		    2: sh:=sh+'Embest';
		    3: sh:=sh+'Sony Japan';
		  else sh:=sh+'0x'+Hex(C,2);
		end; // case
	  end;
	end; // else Log_Writeln(LOG_ERROR,'Get_CPU_INFO_Init: Rev:'+cpurevs+' Hardware:'+cpu_hw+' Processor:'+cpu_proc+' no known platform');
	AnalyzeRevCode:=sh;
  end;

begin
   cpu_snr:='';   cpu_hw:='';   cpu_proc:=''; cpu_rev:=''; cpu_mips:=''; cpu_feat:=''; cpu_rev_num:=0;
   cpu_fmin:='';  cpu_fcur:=''; cpu_fmax:=''; os_rev:='';  uname:=''; 	 cpu_machine:='';
   cpu_cores:=0;  I2C_busnum:=0; status_led_GPIO:=0; 
   RPI_bType:=0;
   for lw:=1 to max_pins_c do RPIHDR_Desc[lw]:='';
   connector_pin_count:=40; 
   cpu_freq:= 700000000; pll_freq:=2000000000; 
  {$IFDEF UNIX}  
	ts:=TStringList.Create;
	call_external_prog(LOG_NONE,proc3_c,sh); 			 os_rev:= 		RM_CRLF(sh);
	call_external_prog(LOG_NONE,proc2_c+'_min_freq',sh); cpu_fmin:=		RM_CRLF(sh);
	call_external_prog(LOG_NONE,proc2_c+'_cur_freq',sh); cpu_fcur:=		RM_CRLF(sh);
	call_external_prog(LOG_NONE,proc2_c+'_max_freq',sh); cpu_fmax:=		RM_CRLF(sh);
	call_external_prog(LOG_NONE,'uname -a',			sh); uname:=   		RM_CRLF(sh);
	call_external_prog(LOG_NONE,'uname -m',			sh); cpu_machine:=	RM_CRLF(sh);

    if not getvcgencmd('arm', cpu_freq)	then cpu_freq:= 700000000; 	
    lw:=round(2*pllc_freq_c/1000000);
	pll_freq:=floor(2400 div lw)*lw*1000000; if pll_freq>0 then ;
//  writeln('CPU Freq: ',cpu_fmin,' ',cpu_fcur,' ',cpu_fmax,' ',cpu_freq,' ',pllc_freq_c,' ',pll_freq);
	if call_external_prog(LOG_NONE,proc1_c,ts)=0 then
    begin
      I2C_busnum:=1; 	status_led_GPIO:=47;   
      cpu_rev_num:=0; 	GPIO_map_idx:=2; 
	  cpu_snr:= cpuinfo_unix('Serial',	 anz);		// e.g. 0000...
	  cpu_hw:=  cpuinfo_unix('Hardware', anz);		// e.g. BCM2709
	  cpu_proc:=cpuinfo_unix('Processor',cpu_cores);
	  cpu_mips:=cpuinfo_unix('BogoMIPS', anz);
	  cpu_feat:=cpuinfo_unix('Features', anz);
	  cpu_rev:= cpuinfo_unix('Revision', anz);		// e.g. a01041 
	  cpu_rev:= AnalyzeRevCode(cpu_rev); 			// new style
//	  writeln(cpu_rev);

(*	  if Str2Num('0x'+cpu_rev,lw) and ((Pos('BCM',cpu_hw)=1)) then
	  begin
//writeln('cpuinfo ',hex(lw,8));
// http://elinux.org/RPI_HardwareHistory
// http://www.raspberrypi-spy.co.uk/2012/09/checking-your-raspberry-pi-board-version/
// https://www.raspberrypi.org/documentation/hardware/raspberrypi/revision-codes/README.md
        case (lw and $7fffff) of // mask out overvoltage bit
          $00..$03 : cpu_rev:=RPI_SetInfo(cpu_rev,'B',  1.0,0,1,16,26, 256);
	      $04..$06 : cpu_rev:=RPI_SetInfo(cpu_rev,'B',  2.0,1,2,16,26, 256);
		  $07..$09 : cpu_rev:=RPI_SetInfo(cpu_rev,'A',  2.0,1,2,16,26, 256);
		  $0d..$0f : cpu_rev:=RPI_SetInfo(cpu_rev,'B',  2.0,1,2,16,26, 512);
		  $10:		 cpu_rev:=RPI_SetInfo(cpu_rev,'B+', 1.0,0,2,47,40, 512);
		  $13:		 cpu_rev:=RPI_SetInfo(cpu_rev,'B+', 1.2,0,2,47,40, 512);
		  $11,$14  : cpu_rev:=RPI_SetInfo(cpu_rev,'CM1',1.1,0,2,47, 0, 512); 	// ComputeModule
		  $12,$15  : cpu_rev:=RPI_SetInfo(cpu_rev,'A+', 1.1,0,2,47,40, 256);
		  $100021  : cpu_rev:=RPI_SetInfo(cpu_rev,'A+', 1.1,1,2,47,40, 512);
		  $100032  : cpu_rev:=RPI_SetInfo(cpu_rev,'B+', 1.2,1,2,47,40, 512);
		  $100092  : cpu_rev:=RPI_SetInfo(cpu_rev,'Z',  1.2,0,2,47,40, 512); 	// PiZero (900092)
		  $100093  : cpu_rev:=RPI_SetInfo(cpu_rev,'Z',  1.3,0,2,47,40, 512); 	// PiZero (900093)
		  $1000c1  : cpu_rev:=RPI_SetInfo(cpu_rev,'ZW', 1.1,0,2,47,40, 512); 	// PiZero (9000c1)
		  $2020a0  : cpu_rev:=RPI_SetInfo(cpu_rev,'CM3',1.0,0,2,47, 0,1024); 	// ComputeModule3
		  $201040  : cpu_rev:=RPI_SetInfo(cpu_rev,'2B', 1.0,1,2,47,40,1024); 	// Pi2B (a01040 Sony, UK)
		  $221041  : cpu_rev:=RPI_SetInfo(cpu_rev,'2B', 1.1,1,2,47,40,1024); 	// Pi2B  
		  $201041  : cpu_rev:=RPI_SetInfo(cpu_rev,'2B', 1.1,1,2,47,40,1024); 	// Pi2B
		  $222042  : cpu_rev:=RPI_SetInfo(cpu_rev,'2B', 1.2,1,2,47,40,1024); 	// Pi2B with BCM2837	
		  $202082  : cpu_rev:=RPI_SetInfo(cpu_rev,'3B', 1.2,1,2,47,40,1024);	// Pi3B (a02082 Sony, UK)	  
		  $222082  : cpu_rev:=RPI_SetInfo(cpu_rev,'3B', 1.2,1,2,47,40,1024);	// Pi3B (a22082 Embest, China)																
		  $232082  : cpu_rev:=RPI_SetInfo(cpu_rev,'3B', 1.2,1,2,47,40,1024); 	// Pi3B (a32082 Sony, Japan)
		  $2020d3  : cpu_rev:=RPI_SetInfo(cpu_rev,'3B+',1.3,1,2,47,40,1024); 	// Pi3B+(a020d3 Sony, UK)
		  $9020e0  : cpu_rev:=RPI_SetInfo(cpu_rev,'3A+',1.0,1,2,47,40, 512); 	// Pi3A+(9020e0 Sony, UK)
// 	RPI_SetInfo(cpurevs,desc:string; cpurev,I2Cbusnr,gpioidx,slednr,pincnt:byte;memsizMB:word)
		  else LOG_Writeln(LOG_ERROR,'Get_CPU_INFO_Init: (0x'+Hex(lw,8)+') unknown rev:'+cpu_rev+': RPI not supported');
        end; // case   
      end else Log_Writeln(LOG_ERROR,'Get_CPU_INFO_Init: Rev:'+cpu_rev+' Hardware:'+cpu_hw+' Processor:'+cpu_proc+' no known platform'); *)
//    writeln(cpu_rev_num);	 

    end;
	ts.free;   	
  {$ENDIF}
end;

function  Bin(q:longword;lgt:Byte) : string;
{.c shows q in binary representation: bbbb bbbb ... }
var h : string; i : Byte;
begin
  h:='';
  for i := (lgt-1) downto 0 do
  begin
    if ((q and (1 shl i))>0)   then h:=h+'1' else h:=h+'0';
	if ((i mod 4)=0) and (i>0) then h:=h+' ';
  end;
  Bin:=h;
end; { Bin }

function  RPI_GetBuildDateTimeString:string;
var sh:string;
begin
  sh:=StringReplace(prog_build_date,'/','-',[rfReplaceAll,rfIgnoreCase]);
  sh:=sh+'T'+prog_build_time;
  RPI_GetBuildDateTimeString:=sh;
end;

procedure RPI_HDR_SetDesc(HWPin:longint; desc:string);
begin if (HWPin>=1) and (HWPin<=max_pins_c) then RPIHDR_Desc[HWPin]:=copy(desc,1,mdl); end;

function  RPI_mmap_get_info (modus:longint)  : longword;
// https://github.com/raspberrypi/userland/blob/master/host_applications/linux/libs/bcm_host/bcm_host.c
var valu:longword; li:longint; sh:string;
begin 
  valu:=0;
  case modus of
	 1,2 : valu:=PAGE_SIZE;
	 3	 : begin // e.g. for ZeroW: 7e0000002000000002000000
			 call_external_prog(LOG_NONE,'xxd -ps /proc/device-tree/soc/ranges',sh);
			 if not Str2Num('$'+copy(sh,9,8),valu) then	// $20000000
			 begin // old variant
			   valu:=BCM2709_PBASE; // for BCM2709 and BCM2835
			   if (Upper(RPI_hw)='BCM2708') then valu:=BCM2708_PBASE;	// for old RPI
			 end;
//			 writeln('PBase: 0x',Hex(valu,8));		 
		   end;
	 4   : begin {$IFDEF UNIX} valu:=1; {$ELSE} valu:=0; {$ENDIF} end;      (* if run_on_unix ->1 else 0 *)
	 5   : if (Upper({$i %FPCTARGETCPU%})='ARM') then valu:=1 else valu:=0; (* if run_on_ARM  ->1 else 0 *)
	 6	 : begin valu:=1; end;					(* if RPI_Piggyback_board_available -> 1 dummy, for future use *)
	 7   : if ((RPI_mmap_get_info(5)=1) and 
	           ((Upper(RPI_hw)='BCM2708') or
	            (Upper(RPI_hw)='BCM2835') or 								(* new in Linux raspberrypi 4.9.11-v7+ #971 SMP Mon Feb 20 20:44:55 GMT 2017 armv7l GNU/Linux *) 
			    (Upper(RPI_hw)='BCM2836') or 
			    (Upper(RPI_hw)='BCM2837') or 
			    (Upper(RPI_hw)='BCM2709'))) then valu:=1;		   			(* runs on known rpi HW *)  
	 8	 : begin valu:=1; end;												(* if PiFaceBoard_board_available -> 1 dummy, for future use *)
	 9   : begin 
	 	     call_external_prog(LOG_NONE,'uname -v',sh); 						// e.g. #970 SMP Mon Feb 20 19:18:29 GMT 2017
	 	     sh:=Select_Item(sh,' ','',1);										// #970
	 	     sh:=GetNumChar(sh);												// 970
	 	     if not Str2Num(sh,li) then li:=-1;									// dummy, works with kernel above 4.4.50 
	 	     if (li<supminkrnl) or (li>supmaxkrnl) then valu:=1 else valu:=1;	// dummy, supported min./max. kernel version 4.0.5 - 4.4.50
	 	   end;
  end;
  RPI_mmap_get_info:=valu;
end;

function  RPI_BCM2835:boolean; begin RPI_BCM2835:=(Upper(RPI_hw)='BCM2835'); end;

function  RPI_BCM2835_GetNodeValue(node:string; var nodereturn:string):longint;
var res:longint;
begin
  res:=-1; 
  if RPI_BCM2835 then
  begin
   call_external_prog(LOG_NONE,'xxd -ps '+node,nodereturn);
   if not Str2Num('$'+GetHexChar(nodereturn),res) then res:=-1; 
// nodereturn:=StrHex(nodereturn); // if return is ASCII text
  end;
  RPI_BCM2835_GetNodeValue:=res;
end;
  
function  RPI_FW_open:longint;
begin
  with rpi_fw_api do
  begin
	if (hndl=-1) then
	begin
	  hndl:=fpopen(rpi_fw_dev, O_NONBLOCK);
	  if (hndl=-1) then LOG_Writeln(LOG_ERROR,'RPI_FW_open: can not open '+rpi_fw_dev);
	end;
	RPI_FW_open:=hndl;
  end; // with
end;

procedure  RPI_FW_close;
begin
  with rpi_fw_api do
  begin
	if (hndl<>-1) then 
	  if (fpclose(hndl)=-1) then LOG_Writeln(LOG_ERROR,'RPI_FW_close: can not close '+rpi_fw_dev);
  end; // with
end;

function  RPI_FW_property(req,tag:longword; tag_data:pointer; buf_size:byte):longint;
// https://github.com/6by9/rpi3-gpiovirtbuf
var res:longint; p:array[0..((256 div 4)+6)] of longword; //n:longint;
begin
  res:=-1;
  if (rpi_fw_api.hndl<>-1) then
  begin
	p[0]:=(5+1 + (buf_size div 4)) * sizeof(tag);
	p[1]:=req;						// TAG_STATUS_REQUEST
	p[2]:=tag;						// tag
	p[3]:=buf_size;					// buf_size
	p[4]:=0;						// req_resp_size
	Move(tag_data^,p[5],buf_size);	// Move(src^, dest^, size);
	p[5+(buf_size div 4)]:=TAG_PROPERTY_END;
//	for n:=0 to (5+(buf_size div 4)) do writeln(n:2,'. ',Hex(p[n],8)); writeln;	
{$RANGECHECKS OFF} 				
	if (fpioctl(rpi_fw_api.hndl,IOCTL_TAG_PROPERTY,addr(p[0]))<>-1) then
	begin
	  if (p[1]=TAG_STATUS_SUCCESS) then
	  begin
//		for n:=0 to (5+(buf_size div 4)) do writeln(n:2,'. ',Hex(p[n],8));	
		Move(p[5],tag_data^,buf_size);
		res:=p[4] and $ff;
	  end else LOG_Writeln(LOG_ERROR,'RPI_FW_property: firmware returned 0x'+Hex(p[1],8));		
	end else LOG_Writeln(LOG_ERROR,'RPI_FW_property: ioctl: IOCTL_TAG_PROPERTY: '+LNX_ErrDesc(fpgeterrno));  
{$RANGECHECKS ON}
  end; // else LOG_Writeln(LOG_ERROR,'RPI_FW_property['+Hex(req,2)+'/0x'+Hex(tag,8)+']: device not opened '+rpi_fw_dev+' use InitRPIfw flag at RPI_HW_Start');
  RPI_FW_property:=res;
end;

function  MACpretty(macstr:string):string;
var n:longint; sh,MAChexStr:string;
begin
  sh:=''; MAChexStr:=StrHex(macstr);
  for n:=1 to Length(MAChexStr) do sh:=sh+Hex(ord(MAChexStr[n]),2)+':';
  MACpretty:=CSV_RemLastSep(sh,':');
end;

function  RPI_FW_Info(req,tag:longword; var FWinfo:string):boolean;
const mm=50;
var _ok:boolean; n,bcnt,wcnt:longint; p:array[0..mm] of longword;
begin
  _ok:=false;
  bcnt:=RPI_FW_property(req,tag,addr(p),sizeof(p)); 
  _ok:=(bcnt>0);
  wcnt:=(bcnt div 4); bcnt:=(bcnt mod 4);
  if _ok then
  begin 
	case tag of
		TAG_GET_BOARD_MAC_ADDRESS:
			begin
			  p[0]:= swap(Hi(p[0])) or (swap(Lo(p[0])) shl 16);
			  p[1]:= swap(Lo(p[1]));
			  FWinfo:=MACpretty(Hex(p[0],8)+copy(Hex(p[1],8),8+1-bcnt*2,bcnt*2));
			end;
		TAG_GET_FIRMWARE_REVISION:
			begin
			  FWinfo:=FormatDateTime('YYYY-MM-DD"T"hh:mm:ss',UnixToDateTime(p[0]));
			end;
		TAG_GET_CLOCK_RATE:
			begin
			  FWInfo:='ClockID 0x'+Hex(p[0],8)+' @ '+Num2Str(p[1],0)+'Hz';
			end;
	  else 	begin
	  		  FWinfo:='';
	  		  if bcnt>0 then FWinfo:=FWinfo+copy(Hex(p[wcnt],8),8+1-bcnt*2,bcnt*2);
			  for n:=wcnt downto 1 do FWinfo:=FWinfo+Hex(p[n-1],8);
	  		end;
	end; // case
  end;
  RPI_FW_Info:=_ok;
end;

procedure RPI_FW_test;
const mm=50;
var i:longint; p:array[0..mm] of longword; lw:longword; info:string; // dt1,dt2,dt3:TDateTime; sh:string;

  procedure ShowArr(msg:string; cnt:longint);
  var _n,_cnt:longint;
  begin 
    if cnt>0 then 
    begin
	  writeln(msg+'(',cnt,'byte):');
      _cnt:=(cnt div 4); if (cnt mod 4)>0 then inc(_cnt);
	  for _n:=1 to _cnt do writeln(_n:4,'. 0x',Hex(p[_n-1],8));
    end;	
  end;

begin
  RPI_FW_open;	// no need, if rpi_hal was init with InitRPIfw flag
  
  i:=RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_BOARD_REVISION,addr(p),sizeof(p)); 	ShowArr('rev',i); 
  if RPI_FW_Info(TAG_STATUS_REQUEST,TAG_GET_BOARD_REVISION,info) then writeln(info);	writeln;
  
  i:=RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_BOARD_SERIAL,addr(p),sizeof(p)); 	ShowArr('snr',i); 
  if RPI_FW_Info(TAG_STATUS_REQUEST,TAG_GET_BOARD_SERIAL,info) then writeln(info);	writeln;
  
  i:=RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_BOARD_MAC_ADDRESS,addr(p),sizeof(p)); ShowArr('MAC',i); 
  if RPI_FW_Info(TAG_STATUS_REQUEST,TAG_GET_BOARD_MAC_ADDRESS,info) then writeln(info);writeln;
  
  i:=RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_FIRMWARE_REVISION,addr(lw),sizeof(lw));ShowArr('fw',i); 
  if RPI_FW_Info(TAG_STATUS_REQUEST,TAG_GET_FIRMWARE_REVISION,info) then writeln(info);writeln;
  
  p[0]:=$3; // get ARM clock
  i:=RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_CLOCK_RATE,addr(lw),sizeof(lw));ShowArr('ClockARM',i); 
  if RPI_FW_Info(TAG_STATUS_REQUEST,TAG_GET_CLOCK_RATE,info) then writeln(info);writeln;

  if RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_TEMPERATURE,addr(p),8)>0
	then writeln('temp: 0x',Hex(p[1],8),' ',(p[1]/1000):5:2,' celsius'); 
  
  if RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_MAX_TEMPERATURE,addr(p),8)>0
	then writeln('tmax: 0x',Hex(p[1],8),' ',(p[1]/1000):5:2,' celsius');
	
  if RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_VC_MEMORY,addr(p),8)>0
	then writeln('VCmem:  0x',Hex(p[1],8),' ',p[1]:10,' Bytes @ 0x'+Hex(p[0],8));
	
  if RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_ARM_MEMORY,addr(p),8)>0
	then writeln('ARMmem: 0x',Hex(p[1],8),' ',p[1]:10,' Bytes @ 0x'+Hex(p[0],8));
	
  p[0]:=$3; // get ARM clock
  i:=RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_CLOCK_RATE,addr(p),sizeof(p)); 		
  if i>0 then begin ShowArr('ClockArm',i); writeln(p[1],'Hz'); writeln; end;
  
  p[0]:=$4; // get Core clock
  i:=RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_CLOCK_RATE,addr(p),sizeof(p)); 		
  if i>0 then begin ShowArr('ClockCore',i); writeln(p[1],'Hz'); writeln; end;

  p[0]:=$3; // get config of gpio 3
  i:=RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_GPIO_CONFIG,addr(p),sizeof(p));		ShowArr('GPIO3 config',i);	writeln;																	

//i:=RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_CLOCKS,addr(p),sizeof(p)); 			ShowArr('clocks',i); 		writeln;
  
(*dt1:=now;		// speed testing
  writeln(GetXMLTimeStamp(dt1));
  for lw:=1 to 1000 do call_external_prog(LOG_NONE,'cat '+rpi_cpu_temp_dev_c,sh);	// takes 70secs
  dt2:=now; writeln(GetXMLTimeStamp(dt2));
  
  for lw:=1 to 1000 do RPI_FW_property(TAG_GET_TEMPERATURE,addr(p),8);		// takes 30msecs !!
  dt3:=now;	writeln(GetXMLTimeStamp(dt3)); *)
  
//RPI_FW_close; no need to close is done automatically by exit procedure
end;

//RPI_MBX_msg_t

//#define MAILBOX ((volatile __attribute__((aligned(4))) struct MailBoxRegisters*)(uintptr_t)(RPi_IO_Base_Addr + 0xB880));
// http://www.valvers.com/open-software/raspberry-pi/step05-bare-metal-programming-in-c-pt5/
// https://github.com/vanvught/rpidmx512/blob/master/lib-bcm2835/src/bcm2835_vc.c

procedure RPI_MBX_msgshow(msgptr:RPI_MBX_msgPTR_t);
begin
  with msgptr^ do
  begin
	writeln('  msg_size:      0x',Hex(msg_size,8));
	writeln('  request_code:  0x',Hex(request_code,8));
//	with tag do
	begin
	  writeln('    tag_id:      0x',Hex(tag_id,8));
	  writeln('    buffer_size: 0x',Hex(buffer_size,8));
	  writeln('    data_size:   0x',Hex(data_size,8)); 
	  writeln('    dev_id:      0x',Hex(dev_id,8)); 
	  writeln('    val:         0x',Hex(val,8)); 		
	end; // with
	writeln('  end_tag:       0x',Hex(end_tag,8));
  end; // with
end;

procedure RPI_MBX_msgfill(var msg:RPI_MBX_msg_t; reqcode,tagid,bsiz,dsiz,devid,value:longword);
begin
  with msg do
  begin
	msg_size:=		sizeof(msg);
	request_code:=	reqcode;		// BCM2837_MBOX_REQUEST_CODE = $00000000;
//	with tag do
	begin
	  tag_id:=		tagid;
	  buffer_size:=	bsiz;			// ResponseLength
	  data_size:=	dsiz;			// RequestLength
	  dev_id:=		devid;
	  val:=			value;		
	end; // with
	end_tag:=		0;				// structure terminator
  end; // with
end;

function  RPI_MBX_empty:boolean;
const RPI3_MAILBOX_TIMEOUT=1000;
var _ok:boolean; lw:longword; timo:TDateTime;
begin
  _ok:=true; SetTimeOut(timo,RPI3_MAILBOX_TIMEOUT);
  while _ok and ((BCM_GETREG(MBX_STATUS0) and MB_EMPTY)<>MB_EMPTY) do
  begin 
    lw:=BCM_GETREG(MBX_READ0); if lw=0 then ; // dummy
	_ok:=(not TimeElapsed(timo));
	delay_msec(1);
  end;
  RPI_MBX_empty:=_ok;
end;

function  RPI_MBX_read(channel:longword):longword;
// does not work, work in progress
const RPI3_MAILBOX_TIMEOUT=1000;
var _ok:boolean; _value:longword; timo:TDateTime;
begin
  _ok:=false; _value:=MB_CHANNEL_ERROR;
  if (channel<=MB_CHANNEL_GPU) then
  begin
	_ok:=true; SetTimeOut(timo,RPI3_MAILBOX_TIMEOUT);
	repeat
	  while ((BCM_GETREG(MBX_STATUS0) and MB_EMPTY)<>0) and _ok do
	  begin // wait until data is avail in MBX or timeout
	  	_ok:=(not TimeElapsed(timo));
	  	delay_msec(1);
	  end;
	  if _ok then _value:=BCM_GETREG(MBX_READ0);
writeln('read1: 0x',Hex(_value,8),' ',_ok);
	until ((_value and $f)=channel) or (not _ok);
	if (not _ok) then
	begin
	  LOG_Writeln(LOG_ERROR,'RPI_MBX_read['+Hex(channel,2)+']: timeout');
	  _value:=MB_CHANNEL_ERROR;
	end else _value:=_value and (not $f); // _value:=_value shr 4; 
  end else LOG_Writeln(LOG_ERROR,'RPI_MBX_read['+Hex(channel,2)+']: wrong channel 0x'+Hex(channel,2));
writeln('read2: 0x',Hex(_value,8),' ',_ok);
  RPI_MBX_read:=_value;
end;

function  RPI_MBX_write(channel,value:longword; xxx:boolean):boolean;
const RPI3_MAILBOX_TIMEOUT=1000;
// does not work, work in progress
var _ok:boolean; timo:TDateTime;
begin
  _ok:=false;
  writeln('write0: value:0x',Hex(value,8));
  if (channel<=MB_CHANNEL_GPU) then
  begin // GPU_MEM_BASE
// ??????????? #define BUS_ADDRESS(phys) (((phys) & ~0xC0000000) | GPU_MEM_BASE) 
	value:=(value and (not $0f)) or channel;
	if xxx then value:=(value and (not GPU_MEM_BASE)) or GPU_MEM_BASE;
//value:=(value or $3B400000);
	_ok:=true; SetTimeOut(timo,RPI3_MAILBOX_TIMEOUT);
	
	while ((BCM_GETREG(MBX_STATUS1) and MB_FULL)<>0) and _ok do
	begin // wait until MBX is empty or timeout
	  _ok:=(not TimeElapsed(timo));
	  delay_msec(1);
	end;
	
writeln('write1: value:0x',Hex(value,8));
	if _ok 	then BCM_SETREG(MBX_WRITE1,value) 
			else LOG_Writeln(LOG_ERROR,'RPI_MBX_write['+Hex(channel,2)+']: timeout');
  end else LOG_Writeln(LOG_ERROR,'RPI_MBX_write['+Hex(channel,2)+']: wrong channel 0x'+Hex(channel,2));
writeln('write2: ',_ok);
  RPI_MBX_write:=_ok;
end;

function  RPI_MBX_Call(channel:longword; msgptr:RPI_MBX_msgPTR_t; var value:longword):boolean;
// does not work, work in progress
var _ok:boolean;
begin
  _ok:=Aligned(msgptr,32);
  if _ok then
  begin
RPI_MBX_msgshow(@msg); writeln;
	_ok:=RPI_MBX_empty;
  	if _ok then
  	begin
	  _ok:=RPI_MBX_write(channel,PtrUInt(msgptr),true);
	  if _ok then
	  begin
	  	value:=RPI_MBX_read(channel);
	  	_ok:=(value<>MB_CHANNEL_ERROR);
	  	if not _ok then LOG_Writeln(LOG_ERROR,'RPI_MBX_Call['+Hex(channel,2)+']: read timeout');
	  end else LOG_Writeln(LOG_ERROR,'RPI_MBX_Call['+Hex(channel,2)+']: can not write');
	end else LOG_Writeln(LOG_ERROR,'RPI_MBX_Call['+Hex(channel,2)+']: not empty timeout');
  end else  LOG_Writeln(LOG_ERROR,'RPI_MBX_Call['+Hex(channel,2)+']: msgptr not aligned');
  RPI_MBX_Call:=_ok;
end;

function  bcm2835_vc_get0408(tag,devid:longword; var value:longword):boolean;
// https://www.raspberrypi.org/forums/viewtopic.php?t=205382
// https://github.com/raspberrypi/firmware/wiki/Mailbox-property-interface
// https://github.com/6by9/rpi3-gpiovirtbuf
var _ok:boolean; msg:RPI_MBX_msg_t;
begin
  _ok:=false;
  RPI_MBX_msgfill(msg,0,tag,8,4,devid,0); 
  _ok:=RPI_MBX_write(MB_CHANNEL_TAGS,PtrUInt(@msg),true);			// sent the message
  if _ok then
  begin													
	RPI_MBX_read  	(MB_CHANNEL_TAGS);					// clear the response
	if (msg.request_code=MB_CHANNEL_SUCCESS) then
	  if (msg.dev_id=devid) then value:=msg.val else _ok:=false
	else _ok:=false;
  end;
  bcm2835_vc_get0408:=_ok;
end;

function  bcm2835_vc_get_temperature(var temp:longword):boolean;
begin bcm2835_vc_get_temperature:=bcm2835_vc_get0408(TAG_GET_TEMPERATURE,0,temp); end;

function  bcm2835_vc_get_temperature_max(var temp:longword):boolean;
begin bcm2835_vc_get_temperature_max:=bcm2835_vc_get0408(TAG_GET_MAX_TEMPERATURE,0,temp); end;
(*Unique clock IDs:
    0x000000000: reserved
    0x000000001: EMMC
    0x000000002: UART
    0x000000003: ARM
    0x000000004: CORE
    0x000000005: V3D
    0x000000006: H264
    0x000000007: ISP
    0x000000008: SDRAM
    0x000000009: PIXEL
    0x00000000a: PWM *)
function  bcm2835_vc_get_clock(clockid:longword; var rateHz:longword):boolean;
begin bcm2835_vc_get_clock:=bcm2835_vc_get0408(TAG_GET_CLOCK_RATE,clockid,rateHz); end;

procedure RPI_MBX_test;
// does not work, work in progress
var lw:longword; _ok:boolean; // xmsg:RPI_MBX_msg_t;
begin
  RPI_MBX_msgfill(	msg,
  	0,						// response
  	$00030002,				// mailbox get clock rates
  	8,						// request is 8 bytes long
  	8,						// response expects 8 bytes back
  	3,						// channel 0
  	0);						// empty data field  	

//RPI_MBX_msgshow(@msg); writeln;
writeln('####1  0x',Hex(addr(msg),8),' ',Hex(GPU_MEM_BASE,8));
writeln('stat0  0x',Hex(BCM_REGAdr(MBX_STATUS0),8),' read0  0x',Hex(BCM_REGAdr(MBX_READ0),8));  
writeln('stat1  0x',Hex(BCM_REGAdr(MBX_STATUS1),8),' write1 0x',Hex(BCM_REGAdr(MBX_WRITE1),8)); 

  _ok:=RPI_MBX_Call(MB_CHANNEL_TAGS,@msg,lw);
if _ok then
begin
  writeln('####2  0x',Hex(lw,8),' ',Hex(msg.request_code,8),' ',_ok);
  RPI_MBX_msgshow(@msg); 
end;
  if (msg.request_code=MB_CHANNEL_SUCCESS) then
  begin
	writeln('CPU speed: ',msg.val,' lw:0x',Hex(lw,8));	
  end;
writeln;
//if bcm2835_vc_get_temperature(lw) 	then writeln('GPUtemp: ',lw);
//if bcm2835_vc_get_temperature_max(lw) then writeln('GPUtempm:',lw); 
end;

function RPI_I2C_GetSpeed(bus:byte):longword; 				begin RPI_I2C_GetSpeed:=I2C_bus[bus].I2C_speed; end;
function RPI_I2C_GetFuncs(bus:byte):longword; 				begin RPI_I2C_GetFuncs:=I2C_bus[bus].I2C_funcs; end;
function RPI_I2C_ChkFuncs(bus:byte; funcs:longword):boolean;begin RPI_I2C_ChkFuncs:=((RPI_I2C_GetFuncs(bus) and funcs)=funcs); end;
function RPI_SPI_GetSpeed(bus:byte):longint; 				begin RPI_SPI_GetSpeed:=spi_bus[bus].spi_maxspeed; end;
function RPI_get_GPIO_BASE:longword;						begin RPI_get_GPIO_BASE:=RPI_mmap_get_info(3); end;
function RPI_mmap_run_on_unix:boolean; 						begin RPI_mmap_run_on_unix:=(RPI_mmap_get_info(4)=1); end;
function RPI_run_on_ARM:boolean;       						begin RPI_run_on_ARM :=     (RPI_mmap_get_info(5)=1); end;
function RPI_Piggyback_board_available  : boolean; 			begin RPI_Piggyback_board_available:=(RPI_mmap_get_info(6)=1); end;
function RPI_PiFace_board_available(devadr:byte): boolean; 	begin RPI_PiFace_board_available:=   (RPI_mmap_get_info(8)=1); end;
function RPI_run_on_known_hw:boolean;     					begin RPI_run_on_known_hw := (RPI_mmap_get_info(7)=1); end;
function RPI_platform_ok:boolean; 							begin RPI_platform_ok:= ((RPI_run_on_known_hw) and ((RPI_mmap_get_info(9)=1))) end;

procedure GPIO_MSG_INFO(lvl:T_ERRORlevel; msg:string; gpio:longword; portfkt:t_port_flags);
begin
  Log_Writeln(lvl,msg+'GPIO'+Num2Str(gpio,0)+' set '+GetEnumName(TypeInfo(t_port_flags),ord(portfkt)));   
end;

function  GPIO_get_ALTMask(gpio:longword; altfunc:t_port_flags):longword;
//INPUT=0; OUTPUT=1; ALT0=4; ALT1=5; ALT2=6; ALT3=7; ALT4=3; ALT5=2;
var msk,afkt:longword;
begin
  afkt:=ord(altfunc) and $7; 
  if (altfunc=INPUT) then afkt:=7; // Reset Mask
  msk:=(afkt shl ((gpio mod 10)*3));
  GPIO_get_ALTMask:=msk;
end;

procedure GPIO_get_mask_and_idxOfs(regidx,gpio:longword; var idxofs:longint; var mask:longword);
begin
  idxofs:=0; mask:=0;
  case regidx of  
	GPFSEL : begin idxofs:=((gpio mod gpiomax_reg_c) div 10); mask:=(7 shl ((gpio mod 10)*3)); end;
	else     begin idxofs:=((gpio mod gpiomax_reg_c) div 32); mask:=(1 shl ( gpio mod 32));    end;
  end; // case
end;

procedure GPIO_get_mask_and_idx(regidx,gpio:longword; var idxabs,mask:longword);
// out:idxabs gives absolute index
var iofs:longint;
begin
  GPIO_get_mask_and_idxOfs(regidx,gpio,iofs,mask); idxabs:=regidx+iofs; 
end;

function  valid_regidx(regidx:longword):boolean;
var ok:boolean;
begin
 ok:=((mmap_arr<>nil) and (regidx<=BCM270x_RegMaxIdx));
 if not ok then
   LOG_WRITELN(LOG_ERROR,'valid_regidx: not initialized or regidx not valid: '+num2Str(regidx,0));
 valid_regidx:=ok;
end;

function  BCM_REGAdr(idx:longword):longword; begin BCM_REGAdr:=RPI_get_GPIO_BASE+(idx*BCM270x_RegSizInByte); end;

function  BCM_GETREG (regidx:longword):longword; 
begin 
//writeln('Boom: 0x',Hex(regidx,8),' ',regidx);
  BCM_GETREG:=mmap_arr^[regidx]; 
end;

procedure BCM_SETREG (regidx,newval:longword);   begin mmap_arr^[regidx]:=newval; end;

procedure BCM_SETREG (regidx,newval:longword; and_mask,readmodifywrite:boolean);
begin
//if valid_regidx(regidx) then
  begin
    if readmodifywrite then
    begin
	  if and_mask then BCM_SETREG(regidx,BCM_GETREG(regidx) and newval) 
				  else BCM_SETREG(regidx,BCM_GETREG(regidx) or  newval);
    end
	else BCM_SETREG(regidx,newval); 
  end;
end;

procedure MEM_SpeedTest; // just for investigations
// tests access speed to RPI Registers vs. regular memory.  
// result: access to register is around 6 times slower than access to memory !!!
// on a Pi3 Model B
// mem:  199ms
// mmap: 1204ms APMIRQCLRACK Value: 0x544D5241
const loops=10000000;
var i,lw,lw1:longword; dt1,dt2,dt3:TDateTime;
begin
  lw:=1234; lw1:=lw; if lw1>0 then ;
  dt1:=now; for i:=1 to loops do lw1:=lw;
  dt2:=now; for i:=1 to loops do lw1:=mmap_arr^[APMIRQCLRACK]; // 0x544D5241
  dt3:=now; 
  writeln('mem:  ',MilliSecondsBetween(dt2,dt1),'ms');
  writeln('mmap: ',MilliSecondsBetween(dt3,dt2),'ms',' APMIRQCLRACK Value: 0x',Hex(lw1,4));
end;

function  MMAP_start(gpioonly:boolean):integer;
//Set up a memory mapped region to access peripherals
var rslt,errno:longint; lw:longword;
begin
  rslt:=-7; errno:=0; restrict2gpio:=false; GPU_MEM_BASE:=0;
  {$IFDEF LINUX}
    if RPI_run_on_ARM then rslt:=-6 else rslt:=-5; 
    if RPI_run_on_ARM and (mmap_arr=nil) then 
    begin
      if not gpioonly then
      begin
        rslt:=-1; restrict2gpio:=false; 
        mem_fd:=fpOpen('/dev/mem',(O_RDWR or O_SYNC (*or O_CLOEXEC*)));		// open /dev/mem 
	  end
	  else
	  begin 
        rslt:=-2; restrict2gpio:=true; 
        mem_fd:=fpOpen('/dev/gpiomem',(O_RDWR or O_SYNC (*or O_CLOEXEC*)));	// open /dev/gpiomem
      end;
      if mem_fd>=0 then 
      begin // mmap GPIO
	    rslt:=-3;
//writeln('MMAP_start: PSIZ:0x',Hex(BCM270x_PSIZ_Byte,8),' Base: 0x',Hex(RPI_get_GPIO_BASE,8));
		mmap_arr:=fpMMap(pointer(0),BCM270x_PSIZ_Byte,
		                 (PROT_READ or PROT_WRITE),
						 (MAP_SHARED {or MAP_FIXED}),
						 mem_fd,
						 (RPI_get_GPIO_BASE div PAGE_SIZE)
						); 
		if mmap_arr=MAP_FAILED then errno:=fpgeterrno else rslt:=0; 
		fpclose(mem_fd);
		if (rslt=0) and (not restrict2gpio) then
		begin 
		  rslt:=-4; // does not work on ZeroW -> 0 ????
		  lw:=BCM_GETREG(APMIRQCLRACK);
// When reading this register it returns 0x544D5241 which is the ASCII reversed value for "ARMT".
		  if (lw=$544D5241) then rslt:=0 // ok
		  else LOG_Writeln(LOG_ERROR,'MMAP_start: APMIRQCLRACK 0x'+Hex(lw,8));
//writeln('MMAP_start: ',rslt);
		end;
      end;
    end;
  {$ENDIF}
  case rslt of
     0 : Log_writeln(Log_INFO, 'RPI_mmap_init, init successful');
    -1 : Log_writeln(Log_ERROR,'RPI_mmap_init, can not open /dev/mem on target CPU '+{$i %FPCTARGETCPU%}+', result: '+Num2Str(rslt,0));
    -2 : Log_writeln(Log_ERROR,'RPI_mmap_init, can not open /dev/gpiomem on target CPU '+{$i %FPCTARGETCPU%}+', result: '+Num2Str(rslt,0));
    -3 : Log_writeln(Log_ERROR,'RPI_mmap_init, mmap fpgeterrno: '+Num2Str(errno,0)+' result: '+Num2Str(rslt,0));
	-4 : Log_writeln(Log_ERROR,'RPI_mmap_init, can not read test register APMIRQCLRACK');
	-5 : Log_writeln(Log_ERROR,'RPI_mmap_init, not supported rpi platform');
	-6 : Log_writeln(Log_ERROR,'RPI_mmap_init, mmap already initialized');
	-7 : Log_writeln(Log_ERROR,'RPI_mmap_init, no linux platform');
	else Log_writeln(Log_ERROR,'RPI_mmap_init, unknown error, result: '+Num2Str(rslt,0));
  end;
  if rslt=0 then 
  begin
	GPU_MEM_BASE:=GPU_UNCACHED_BASE;
(* todo, set GPU_MEM_BASE for rpi1
#if RASPPI == 1
	#ifdef GPU_L2_CACHE_ENABLED
		#define GPU_MEM_BASE	GPU_CACHED_BASE
	#else
		#define GPU_MEM_BASE	GPU_UNCACHED_BASE
	#endif
#else
	#define GPU_MEM_BASE	GPU_UNCACHED_BASE
#endif *)	
    if restrict2gpio then Log_writeln(Log_WARNING,'RPI_mmap_init, only GPIO access allowed');
  end else mmap_arr:=nil;	
  MMAP_start:=rslt;
end;

procedure MMAP_end;
var rslt:longint;
begin
  rslt:=0;
  {$IFDEF UNIX} 
	if (mmap_arr<>nil) 	then fpMUnMap(mmap_arr,BCM270x_PSIZ_Byte);
  {$ENDIF}
  mmap_arr:=nil; 
  case rslt of
     0 : Log_writeln(Log_INFO, 'RPI_mmap_close, successful '+Num2Str(rslt,0));
    -1 : Log_writeln(Log_ERROR,'RPI_mmap_close, un-mmapping '+Num2Str(rslt,0));
    else Log_writeln(Log_ERROR,'RPI_mmap_close, unknown error '+Num2Str(rslt,0));	
  end;
end;

function  GPIO_HWPWM_capable(gpio:longword; pwmnum:byte):boolean;
var ok:boolean;
begin
  ok:=false;
  if not ok then ok:=((pwmnum=0) and ((gpio=GPIO_PWM0) or (gpio=GPIO_PWM0A0)));
  if not ok then ok:=((pwmnum=1) and ((gpio=GPIO_PWM1) or (gpio=GPIO_PWM1A0)));
  GPIO_HWPWM_capable:=ok;
end;

function  GPIO_HWPWM_capable(gpio:longword):boolean;
begin GPIO_HWPWM_capable:=(GPIO_HWPWM_capable(gpio,0) or GPIO_HWPWM_capable(gpio,1)); end;

function  GPIO_FCTOK(gpio:longint; flags:s_port_flags):boolean;
var _ok:boolean; 
begin
  _ok:=((gpio>=0) and (GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio)>=0));
  if _ok and (PWMHW IN flags) then _ok:=GPIO_HWPWM_capable(gpio);
  if _ok and (FRQHW IN flags) then 
	 _ok:=((gpio=GPIO_FRQ04_CLK0) or (gpio=GPIO_FRQ05_CLK1) or (gpio=GPIO_FRQ06_CLK2) or 
	       (gpio=GPIO_FRQ20_CLK0) or (gpio=GPIO_FRQ32_CLK0) or (gpio=GPIO_FRQ34_CLK0) or
		   (gpio=GPIO_FRQ42_CLK1) or (gpio=GPIO_FRQ43_CLK2) or (gpio=GPIO_FRQ42_CLK1));
  GPIO_FCTOK:=_ok;
end;

function GPIO_get_AltDesc(gpio:longint; altpin:byte; dfltifempty:string):string;
// datasheet page 102 
const maxalt_c=5; res=''; intrnl='<intrnl>';
      Alt_hdr_dsc_c   : array[0..maxalt_c] of array[0..gpiomax_reg_c-1] of string[mdl] = 
  (	// ALT0
    ( ('I2C SDA0'),		('I2C SCL0'),	('I2C SDA1'),	('I2C SCL1'),	('GPCLK0'),
	  ('GPCLK1'),		('GPCLK2'),		('SPI0 CE1/'),	('SPI0 CE0/'),	('SPI0 MISO'),
	  ('SPI0 MOSI'),	('SPI0 SCLK'),	('PWM0'),		('PWM1'),		('TxD0'),
	  ('RxD0'),			(res),			(res),			('PCM CLK'),	('PCM FS'),
	  ('PVM DIN'),		('PCMDOUT'),	(res),			(res),			(res),
	  (res),			(res),			(res),			('SDA0'),		('SCL0'),
	  (res),			(res),			('GPCLK0'),		(res),			('GPCLK0'),
	  ('SPI0 CE1/'),	('SPI0 CE0/'),	('SPI0 MISO'),	('SPI0 MOSI'),	('SPI0 SCLK'),
	  ('PWM0'),		 	('PWM1'),		('GPCLK1'),		('GPCLK2'),		('GPCLK3'),
	  ('PWM1'),			(intrnl),		(intrnl),		(intrnl),		(intrnl),
	  (intrnl),			(intrnl),		(intrnl),		(intrnl)		),
	// ALT1
    ( ('SA5'),			('SA4'),		('SA3'),		('SA2'),		('SA1'),
	  ('SA0'),			('SOE/'),		('SWE/'),		('SD0'),		('SD1'),
	  ('SD2'),			('SD3'),		('SD4'),		('SD5'),		('SD6'),
	  ('SD7'),			('SD8'),		('SD9'),		('SD10'),		('SD11'),
	  ('SD12'),			('SD13'),		('SD14'),		('SD15'),		('SD16'),
	  ('SD17'),			(res),			(res),			('SA5'),		('SA4'),
	  ('SA3'),			('SA2'),		('SA1'),		('SA0'),		('SOE/'),
	  ('SWE/'),			('SD0'),		('SD1'),		('SD2'),		('SD3'),
	  ('SD4'),			('SD5'),		('SD6'),		('SD7'),		('SDA0'),
	  ('SCL0'),			(''),			(''),			(''),			(''),	
	  (''),				(''),			(''),			('')		  ),
	// ALT2	  
	( (res),			(res),			(res),			(res),			(res),
	  (res),			(res),			(res),			(res),			(res),
	  (res),			(res),			(res),			(res),			(res),
	  (res),			(res),			(res),			(res),			(res),
	  (res),			(res),			(res),			(res),			(res),
	  (res),			(res),			(res),			('PCM CLK'),	('PCM FS'),
	  ('PCM DIN'),		('PCM DOUT'),	(res),			(res),			(res),
	  (''),				('TxD0'),		('RxD0'),		('RTS0'),		('CTS0'),
	  (''),				(res),			(res),			(res),			('SDA1'),
	  ('SCL1'),			(''),			(''),			(''),			(''),	
	  (''),				(''),			(''),			('')		  ),
	// ALT3	  
	( (''),				(''),			(''),			(''),			(''),
	  (''),				(''),			(''),			(''),			(''),
	  (''),				(''),			(''),			(''),			(''),
	  (''),				('CTS0'),		('RTS0'),		('BSCL'),		('BSCL'),
	  ('BSCL'),			('BSCL'),		('SD1 CLK'),	('SD1 CMD'),	('SD1 DAT0'),
	  ('SD1 DAT1'),		('SD1 DAT2'),	('SD1 DAT3'),	(res),			(res),
	  ('CTS0'),			('RTS0'),		('TxD0'),		('RxD0'),		(res),
	  (res),			(res),			(res),			(res),			(res),
	  (res),			(res),			(res),			(res),			(res),
	  (''),				(''),			(''),			(''),			(''),	  
	  (''),				(''),			(''),			('')		),
	// ALT4
	( (''),				(''),			(''),			(''),			(''),
	  (''),				(''),			(''),			(''),			(''),
	  (''),				(''),			(''),			(''),			(''),
	  (''),				('SPI1 CE2/'),	('SPI1 CE1/'),	('SPI1 CE0/'),	('SPI1 MISO'),
	  ('SPI1 MOSI'),	('SPI1 SCLK'),	('ARM TRST'),	('ARM RTCK'),	('ARM TDO'),
	  ('ARM TCK'),		('ARM TDI'),	('ARM TMS'),	(''),			(''),
	  (''),				(''),			(''),			(''),			(''),
	  (''),				(''),			(''),			(''),			(''),
	  ('SPI2 MISO'),	('SPI2 MOSI'),	('SPI2 SCLK'),	('SPI2 CE0/'),	('SPI2 CE1/'),
	  ('SPI2 CE2/'),	(''),			(''),			(''),			(''),	  	  
	  (''),				(''),			(''),			('')		),
	// ALT5
	( (''),				(''),			(''),			(''),			('ARM TDI'),
	  ('ARM TDO'),		('ARM RTCK'),	(''),			(''),			(''),
	  (''),				(''),			('ARM TMS'),	('ARM TCK'),	('TxD1'),
	  ('RxD1'),			('CTS1'),		('RTS1'),		('PWM0'),		('PWM1'),
	  ('GPCLK0'),		('GPCLK1'),		(''),			(''),			(''),
	  (''),				(''),			(''),			(''),			(''),
	  ('CTS1'),			('RTS1'),		('TxD1'),		('RxD1'),		(''),
	  (''),				(''),			(''),			(''),			(''),
	  ('TxD1'),			('RxD1'),		('RTS1'),		('CTS1'),		(''),	
	  (''),				(''),			(''),			(''),			(''),	  
	  (''),				(''),			(''),			('')		)	  
  );
var sh:string;
begin
{$warnings off}
  if (altpin>=0) and (altpin<=maxalt_c) and 
	 (gpio>=0)   and (gpio<gpiomax_reg_c)    then sh:=Alt_hdr_dsc_c[altpin,gpio] else sh:='';
{$warnings on}  
  if sh='' then sh:=dfltifempty;
  GPIO_get_AltDesc:=sh;
end; //GPIO_get_AltDesc

function GPIO_get_altval(RegAltVal:byte):byte;
var b:byte;
begin
  b:=(RegAltVal and $07);
  case b of 
    $02..$03: 	b:=$07-b; 	// A04 A05
	$04..$05,
	$06..$07: 	b:=b-$04;	// A00 A01 A02 A03
  end;
  GPIO_get_altval:=b;
end;

function gpiofkt(gpio:longint; gpiofunc:byte; desclong:boolean):string;
var s:string; av:byte;
begin
  case (gpiofunc and $7) of
	$00 : 		s:='IN '; 
	$01 : 		s:='OUT'; 
	$02..$07: 	begin 
				  av:=GPIO_get_altval(gpiofunc);
				  s:='A'+Num2Str(av,0)+' '; 
				  if desclong then s:=GPIO_get_AltDesc(gpio,av,s); 
				end; 
	else  s:='';
  end;
 gpiofkt:=s;
end;

function  GPIO_get_fkt_value(gpio:longint):byte;
var regidx,mask:longword; altval:byte;
begin
  altval:=$00;
  if (gpio>=0) and (gpio<gpiomax_reg_c) then
  begin
    GPIO_get_mask_and_idx(GPFSEL,gpio,regidx,mask);
	altval:=Byte(((BCM_GETREG(regidx) and mask) shr ((gpio mod 10)*3)) and $7);
  end;  
  GPIO_get_fkt_value:=altval;
end;

function get_reg_desc(regidx,regcontent:longword):string;
var s:string;
begin
  s:='';
  case regidx of
  	GPFSEL..GPFSEL+5: 		s:='GPFSEL'+  Num2Str(longword(regidx-GPFSEL),0); 
	GPSET ..GPSET+1: 		s:='GPSET'+   Num2Str(longword(regidx-GPSET),0); 
    GPCLR ..GPCLR+1: 		s:='GPCLR'+   Num2Str(longword(regidx-GPCLR),0);
	GPLEV ..GPLEV+1: 		s:='GPLEV'+   Num2Str(longword(regidx-GPLEV),0);
	GPEDS ..GPEDS+1: 		s:='GPEDS'+   Num2Str(longword(regidx-GPEDS),0);
	GPREN	..GPREN+1: 		s:='GPREN'+   Num2Str(longword(regidx-GPREN),0); 	
	GPFEN ..GPFEN+1: 		s:='GPFEN'+   Num2Str(longword(regidx-GPFEN),0); 
	GPHEN  ..GPHEN+1: 		s:='GPHEN'+   Num2Str(longword(regidx-GPHEN),0);
	GPLEN	..GPLEN+1: 		s:='GPLEN'+   Num2Str(longword(regidx-GPLEN),0); 
	GPAREN..GPAREN+1: 		s:='GPAREN'+  Num2Str(longword(regidx-GPAREN),0);
	GPAFEN..GPAFEN+1: 		s:='GPAFEN'+  Num2Str(longword(regidx-GPAFEN),0);
	GPPUD: 					s:='GPPUD'+   Num2Str(longword(regidx-GPPUD),0);
	GPPUDCLK..GPPUDCLK+1: 	s:='GPPUDCLK'+Num2Str(longword(regidx-GPPUDCLK),0);
	STIMCS: 				s:='SYSTIMCS'; 
	STIMCLO: 				s:='SYSTIMCLO';
	STIMCHI: 				s:='SYSTIMCHI';
	STIMC0: 				s:='SYSTIMC0';
	STIMC1: 				s:='SYSTIMC1';
	STIMC2: 				s:='SYSTIMC2';
	STIMC3: 				s:='SYSTIMC3';
	SPI0_CS:				s:='CS';
	SPI0_FIFO:	 			s:='FIFO';
    SPI0_CLK:				s:='CLK';	
	SPI0_DLEN:				s:='DLEN';
	SPI0_LTOH:				s:='LTOH';
	SPI0_DC:				s:='DC';		
	I2C0_C:					s:='CONTROL';
	I2C0_S:					s:='STATUS';
	I2C0_DLEN:				s:='DLEN';
	I2C0_A:					s:='SLAVEADR';
	I2C0_FIFO:				s:='FIFO';
	I2C0_DIV:				s:='DIV';
	I2C0_DEL:				s:='DEL';
	I2C0_CLKT:				s:='CLKT';	
	I2C1_C:					s:='CONTROL';
	I2C1_S:					s:='STATUS';
	I2C1_DLEN:				s:='DLEN';
	I2C1_A:					s:='SLAVEADR';
	I2C1_FIFO:				s:='FIFO';
	I2C1_DIV:				s:='DIV';
	I2C1_DEL:				s:='DEL';
	I2C1_CLKT:				s:='CLKT';
	PWMCTL: 				s:='PWMCTL'; 
	PWMSTA: 				s:='PWMSTA';
	PWMDMAC: 				s:='PWMDMAC';
	PWM0RNG: 				s:='PWM0RNG';
	PWM0DAT: 				s:='PWM0DAT';
	PWM0FIF: 				s:='PWM0FIF';
	PWM1RNG: 				s:='PWM1RNG';
	PWM1DAT: 				s:='PWM1DAT';
	GMGP0CTL: 				s:='GMGP0CTL'; 
	GMGP0DIV: 				s:='GMGP0DIV';
	GMGP1CTL: 				s:='GMGP1CTL';
	GMGP1DIV: 				s:='GMGP1DIV';
	GMGP2CTL: 				s:='GMGP2CTL';
	GMGP2DIV: 				s:='GMGP2DIV';
	PWMCLKCTL: 				s:='PWMCLKCTL';
	PWMCLKDIV: 				s:='PWMCLKDIV';
	APMVALUE:				s:='APMVALUE';
	APMCTL:					s:='APMCTL';
	APMIRQCLRACK:			s:='APMIRQCLRACK';
	APMRAWIRQ:				s:='APMRAWIRQ';
	APMMaskedIRQ:			s:='APMMaskedIRQ';
	APMReload: 				s:='APMReload';
	APMPreDivider: 	  		s:='APMPreDivider';
	APMFreeRunCounter: 		s:='APMFreeRunCounter';
	Q4LP_CTL :				s:='CTL'; 
	Q4LP_CTIMPRE :			s:='CTIMPRE';
	Q4LP_LOCINTRTG :		s:='LOCINTRTG';
	Q4LP_GPUINTRTG :		s:='GPUINTRTG';
	Q4LP_CoreTimAccLS :		s:='CTIMLSB';
	Q4LP_CoreTimAccMS :		s:='CTIMMSB';	  
	Q4LP_LOCTIMCTL :		s:='LOCTIMCTL';
	Q4LP_LOCTIMCTL+1:		s:='LOCTIMFLG';
	Q4LP_Core0IntCtl..
	Q4LP_Core0IntCtl+3:		s:='C'+Num2Str(longword(regidx-Q4LP_Core0IntCtl),0)+'INTCTL';
	Q4LP_Core0IrqSrc..
	Q4LP_Core0IrqSrc+3:		s:='C'+Num2Str(longword(regidx-Q4LP_Core0IrqSrc),0)+'IRQSRC';
	Q4LP_Core0FIQSrc..
	Q4LP_Core0FIQSrc+3:		s:='C'+Num2Str(longword(regidx-Q4LP_Core0FIQSrc),0)+'FIQSRC';
	else 					s:='['+Hex(RPI_get_GPIO_BASE+(regidx*BCM270x_RegSizInByte),8)+']'; 
						  //s:='Reg['+Num2Str(longword(regidx),0)+']';
  end; // case
  s:=Get_FixedStringLen(s,wid1,false)+': '+Bin(regcontent,32)+' 0x'+Hex(regcontent,8);  
  get_reg_desc:=s;
end;

function  GPIO_get_desc(regidx,regcontent:longword) : string; 
var s:string; pin:integer;
begin
  s:='';  
  case regidx of
    GPFSEL..GPFSEL+5 : begin
                         for pin:= 9 downto 0 do
						   s:=s+'P'+LeadingZero(pin+(regidx-GPFSEL)*10)+':'+
						      gpiofkt((pin+(regidx-GPFSEL)*10),
							           GPIO_get_fkt_value((pin+(regidx-GPFSEL)*10)),false)+' ';					 
	                   end;
  end;
  GPIO_get_desc:=s;
end;
  
procedure DESC_HWPIN(pin:longint; var desc,dir,pegel:string);
//  WRONGPIN=-100; UKN=-99; V5=-98; V33=-97; GND=-96; DNC=-95; 
var gpio:longint; altval,av:byte;
begin
  gpio:=GPIO_MAP_HDR_PIN_2_GPIO_NUM(pin); dir:=''; pegel:='';
  case gpio of
	V5:			desc:='5V';
	V33:		desc:='3.3V';
	GND:		desc:='GND';
	IDSC:		desc:='ID SC';
	IDSD:		desc:='ID SD';
	DNC:		desc:='';
	UKN:		desc:='';
	WRONGPIN:	desc:='';
	else		begin
				  gpio:=abs(gpio);
				  if (pin>=1) and (pin<=max_pins_c) 
				    then desc:=RPIHDR_Desc[pin] else desc:='';
				  altval:=GPIO_get_fkt_value(gpio);
				  dir:=gpiofkt(gpio,altval,false);
				  case altval of
					$00: begin pegel:=Bool2LVL(GPIO_get_PIN(gpio)); end; // IN 
					$01: begin pegel:=Bool2LVL(GPIO_get_PIN(gpio)); end; // OUT
					else begin 
						   av:=GPIO_get_altval(altval); 
						   if desc='' then desc:=GPIO_get_AltDesc(gpio,av,desc); 
//						   sh:='A0'+Num2Str(av,1);
						 end;
				  end; // case
				  if desc='' then desc:='GPIO'+LeadingZero(gpio);
				end;
  end; //case
end;

function  CEPstring(cmd:string):string; var sh:string; begin call_external_prog(Log_NONE,cmd,sh); CEPstring:=sh; end;

function  HAT_vendor:string;	 begin HAT_vendor:= 	CEPstring('cat /proc/device-tree/hat/vendor'); 		end;
function  HAT_product:string; 	 begin HAT_product:=	CEPstring('cat /proc/device-tree/hat/product'); 	end;
function  HAT_product_id:string; begin HAT_product_id:=	CEPstring('cat /proc/device-tree/hat/product_id');	end;
function  HAT_product_ver:string;begin HAT_product_ver:=CEPstring('cat /proc/device-tree/hat/product_ver');	end;
function  HAT_uuid:string; 		 begin HAT_uuid:=		CEPstring('cat /proc/device-tree/hat/uuid');		end;
function  HAT_GetInfo(ovrwrt:boolean; duuid,dvendor,dproduct,dsnr:string; dpid,dpver:longword):boolean;
begin
  with HAT_info do
  begin
    uuid:=''; vendor:=''; product:=''; snr:=''; product_id:=0; product_ver:=0; 
    available:=DirectoryExists('/proc/device-tree/hat'); 
    overwrite:=false; if not available then overwrite:=ovrwrt;
    if available then
    begin
      uuid:=		HAT_uuid;
      vendor:=		HAT_vendor;
      product:=		HAT_product;					// e.g. productname@snr
      snr:=			Select_Item(product,'@','',2);	// snr
      product:=		Select_Item(product,'@','',1);	// productname
      if not Str2Num(HAT_product_id, product_id)  then product_id:= 0;
      if not Str2Num(HAT_product_ver,product_ver) then product_ver:=0;
    end
    else
    begin
      if overwrite then
      begin // e.g. for testing
        SAY(LOG_WARNING,'HAT_GetInfo: HAT_OVRwrite');
		available:=	true;
		uuid:=		duuid;
		vendor:=	dvendor;
		product:=	dproduct;
		snr:=		dsnr;
		product_id:=dpid;
		product_ver:=dpver;
      end;
    end;
    HAT_GetInfo:=available;
  end; // with
end;
function  HAT_GetInfo:boolean; 
begin HAT_GetInfo:=HAT_GetInfo(false,'00000000-0000-0000-0000-000000000000','vendor','product',rpi_snr,0,0); end;

procedure HAT_GetStructInfo(HAT_INFO_tl:TStringList; lgt:byte);
var ovrstr:string;
begin
  with HAT_info do
  begin
    if overwrite then ovrstr:=' (ovr)' else ovrstr:='';
    HAT_INFO_tl.add(Get_FixedStringLen('uuid:',lgt,false)+uuid+ovrstr);
    HAT_INFO_tl.add(Get_FixedStringLen('vendor:',lgt,false)+vendor);
    HAT_INFO_tl.add(Get_FixedStringLen('product:',lgt,false)+product);
    if snr<>'' then HAT_INFO_tl.add(Get_FixedStringLen('snr:',lgt,false)+snr);
    HAT_INFO_tl.add(Get_FixedStringLen('prod_id:',lgt,false)+'0x'+Hex(product_id, 4));
    HAT_INFO_tl.add(Get_FixedStringLen('prod_ver:',lgt,false)+'0x'+Hex(product_ver,4));
  end; // with
end;
procedure HAT_ShowStruct;
var _tl:TStringList;
begin
  _tl:=TStringList.create;
  HAT_GetStructInfo(_tl,10);
  ShowStringList(_tl);
  _tl.free;
end;
procedure HAT_Info_Test;
begin
  if HAT_GetInfo then
  begin
    writeln('HAT Info:');
    HAT_ShowStruct;
  end else Log_Writeln(Log_ERROR,'HAT_Info_Test: no HAT installed');
end;

procedure HAT_EEprom_Map(tl:TStringList; hwname,uuid,vendor,product:string; prodid,prodver,gpio_drive,gpio_slew,gpio_hysteresis,back_power:word; useDefault,EnabIO:boolean);
//https://github.com/raspberrypi/hats/blob/master/eeprom-format.md
//https://github.com/raspberrypi/hats/blob/master/devicetree-guide.md
  procedure la(str:string); begin tl.add(str); end;
var _hwname,_uuid,_vendor,_product,dir,desc,pegel,sh,sh2,sh3:string; _gd,_gs,_gh,_bp,n,pin:word;
begin
  _hwname:=hwname;	if _hwname=''	then _hwname:=Get_Fname(ParamStr(0));
  _uuid:=uuid;		if _uuid=''		then _uuid:=   '00000000-0000-0000-0000-000000000000';
  _vendor:=vendor;	if _vendor=''	then _vendor:= 'ACME Technology Company';
  _product:=product;if _product=''	then _product:='Special Sensor Board';
  _gd:=gpio_drive;	if _gd>15		then _gd:=0;
  _gs:=gpio_slew;	if _gs>3		then _gs:=0;
  _gh:=gpio_hysteresis;	if _gh>3	then _gh:=0;
  _bp:=back_power;	if _bp>3		then _bp:=0;
	la('########################################################################');
	la('# EEPROM settings file for '+_hwname);
	la('# Vendor info');
	la('');
	la('product_uuid '+_uuid);
	la('product_id 0x'+ Hex(prodid, 4));
	la('product_ver 0x'+Hex(prodver,4));
	la('vendor "'+ copy(_vendor, 1,255)+'"');
	la('product "'+copy(_product,1,255)+'"');		
	la('');
	la('########################################################################');
	la('');
	la('# drive strength, 0=default, 1-8=2,4,6,8,10,12,14,16mA, 9-15=reserved');
	la('gpio_drive '+Num2Str(_gd,0));
	la('');
	la('# 0=default, 1=slew rate limiting, 2=no slew limiting, 3=reserved');
	la('gpio_slew '+Num2Str(_gs,0));
	la('');
	la('# 0=default, 1=hysteresis disabled, 2=hysteresis enabled, 3=reserved');
	la('gpio_hysteresis '+Num2Str(_gh,0));
	la('');
	la('# If board back-powers Pi via 5V GPIO header pins:');
	la('# 0 = board does not back-power');
	la('# 1 = board back-powers and can supply the Pi with a minimum of 1.3A');
	la('# 2 = board back-powers and can supply the Pi with a minimum of 2A');
	la('# 3 = reserved');
	la('# If back_power=2 then USB high current mode will be automatically enabled on the Pi');
	la('back_power '+Num2Str(_bp,0));
	la('');
	la('########################################################################');
	la('# GPIO pins, uncomment for GPIOs used on board');
	la('# Options for FUNCTION: INPUT, OUTPUT, ALT0-ALT5');
	la('# Options for PULL: DEFAULT, UP, DOWN, NONE');
	la('# NB GPIO0 and GPIO1 are reserved for ID EEPROM so cannot be set');
	la('');
	    la('#         GPIO  FUNCTION  PULL');
	    la('#         ----  --------  ----');
	for n:= 2 to 27 do
	begin
	  sh:='#'; if EnabIO then sh:=' '; 
	  if useDefault then 
	  begin
	    sh:=sh+'setgpio  '+Get_FixedStringLen(Num2Str(n,0),2,true)+'    INPUT     DEFAULT';
	  end
	  else
	  begin
	    pin:=GPIO_MAP_GPIO_NUM_2_HDR_PIN(n);
	    DESC_HWPIN(pin,desc,dir,pegel);
	    desc:= Get_FixedStringLen(desc,mdl,false);
	    dir:=  Get_FixedStringLen(dir,   3,false);
	    pegel:=Get_FixedStringLen(pegel, 1,false);
	    if dir<>'' then
	    begin
	      sh2:=StringReplace(dir,'IN' ,'INPUT', [rfReplaceAll,rfIgnoreCase]);
	      sh2:=StringReplace(sh2,'OUT','OUTPUT',[rfReplaceAll,rfIgnoreCase]);
	      sh2:=StringReplace(sh2,'A',  'ALT',   [rfReplaceAll,rfIgnoreCase]); 
	      sh2:=Get_FixedStringLen(sh2,10,false);
	      sh3:='DEFAULT';
	      sh:= sh+'setgpio  '+Get_FixedStringLen(Num2Str(n,0),6,false)+sh2+sh3+
	      			'  # '+Num2Str(pin,2)+' '+pegel+' '+Trimme(desc,3);
	    end;  
	  end;
	  if Trimme(sh,3)<>'' then la(sh);
	end; // for
end;

procedure HAT_EEprom_Map_Test;
(*	./eepmake eeprom_mycfg.txt eepcfg.eep
	./eepflash.sh -w -t=24c256 -f=eepcfg.eep
	./eepflash.sh -r -t=24c256 -f=myeep.eep
	./eepdump myeep.eep stuff.eep
	more stuff.eep								*)
var tl:TStringList;
begin
  tl:=TStringList.create;
  HAT_EEprom_Map(tl,'test','','your company','your board',$0001,$0001,0,0,0,2,true,false);
  ShowStringList(tl); // StringList2TextFile('/tmp/eeprom_example.txt',tl);
  tl.free;
end;

procedure GPIO_ConnectorStringList(tl:TStringList);
{ shows the actual configuration of the Hardware Connector. 
V shows the actual logic level of the PIN 'L' is low and 'H' is high level
DIR: IN=Pin is configured as Input, OUT=Output. A0..A5 shows the ALT level. 
pls. see datasheet for definition

PIN Header (rev3;1GB;PI2B;BCM2709;a01041):
Signal    DIR V Pin  Pin V DIR Signal
3.3V             1 ||  2       5V       
I2C SDA1  A0     3 ||  4       5V       
I2C SCL1  A0     5 ||  6       GND      
GPIO04    IN  H  7 ||  8   A0  TxD0     
GND              9 || 10   A0  RxD0     
GPIO17    OUT H 11 || 12 H IN  GPIO18   
GPIO27    IN  L 13 || 14       GND      
GPIO22    IN  L 15 || 16 L IN  GPIO23   
3.3V            17 || 18 L IN  GPIO24   
SPI0 MOSI A0    19 || 20       GND      
SPI0 MISO A0    21 || 22 L IN  GPIO25   
SPI0 SCLK A0    23 || 24   A0  SPI0 CE0/
GND             25 || 26   A0  SPI0 CE1/
ID SD           27 || 28       ID SC    
GPIO05    IN  H 29 || 30       GND      
GPIO06    IN  H 31 || 32 L IN  GPIO12   
GPIO13    IN  L 33 || 34       GND      
GPIO19    IN  L 35 || 36 L IN  GPIO16   
GPIO26    IN  L 37 || 38 L IN  GPIO20   
GND             39 || 40 L IN  GPIO21
}
var pin,pinmax:longint; sh,dir,desc,pegel:string;
begin
  pinmax:=40;
  begin
    sh:='';
	tl.add('PIN Header ('+RPI_rev+'):');
	tl.add('Signal    DIR V Pin  Pin V DIR Signal');
    for pin:= 1 to pinmax do
	begin
	  DESC_HWPIN(pin,desc,dir,pegel);
	  desc:= Get_FixedStringLen(desc,mdl,false);
	  dir:=  Get_FixedStringLen(dir,   3,false);
	  pegel:=Get_FixedStringLen(pegel, 1,false);
	  if (pin mod 2)=0 then 
	  begin 
	    sh:=sh+' || '+Num2Str(pin,2)+' '+pegel+' '+dir+' '+desc; 
		tl.add(sh); 
		sh:=''; 
	  end 
	  else 
	  begin
	    sh:=desc+' '+dir+' '+pegel+' '+Num2Str(pin,2);
	  end;
	end;
  end;
end;

procedure GPIO_ShowConnector;
var tl:TStringList;
begin
  tl:=TStringList.create;
  GPIO_ConnectorStringList(tl);
  ShowStringList(tl);
  tl.free;
end;

function  show_reg(regidx,mode:longword):string;
var data:longword; s:string;
begin 
  data:=BCM_GETREG(regidx);
  s:=get_reg_desc(regidx,data);
  if mode=1 then s:=s+' '+GPIO_get_desc(regidx,data);
  show_reg:=s;
end;

procedure show_regs(desc:string; ofs,startidx,endidx,mode:longword; showhdr:boolean);
var idx:longword; skip:boolean;
begin
  skip:=((mode=2) and (RPI_hw='BCM2708'));
  writeln(Get_FixedStringLen(desc,wid1,false)+': ',Hex(RPI_get_GPIO_BASE+ofs,8));
  if showhdr then
  begin
    write  (Get_FixedStringLen('Adr(1F-00)',wid1,false)+': ');
    for idx:=31 downto 0 do 
      begin write(Hex((idx mod $10),1)); if (idx mod 4)=0 then write(' '); end; writeln;
  end;
  if (not skip) then
  begin
    for idx:=startidx to endidx do writeln(show_reg(idx,mode));
  end
  else writeln(RPI_hw,' processor has no registers here');
end;
procedure show_regs(desc:string; ofs,startidx,endidx,mode:longword);
begin show_regs(desc,ofs,startidx,endidx,mode,true); end;

procedure PADS_show_regs;begin 	show_regs('PADSBase',	PADS_BASE_OFS, PADS_BASE_START,PADS_BASE_LAST,0); end;
procedure GPIO_show_regs;begin 	show_regs('GPIOBase',	GPIO_BASE_OFS, GPIO_BASE,GPIO_BASE_LAST,1); end;
procedure SPI0_show_regs;begin 	show_regs('SPI0Base', 	SPI0_BASE_OFS, SPI0_BASE,SPI0_BASE_LAST,0); end;
procedure I2C0_show_regs;begin 	show_regs('I2C0Base', 	I2C0_BASE_OFS, I2C0_BASE,I2C0_BASE_LAST,0); end;
procedure I2C1_show_regs;begin 	show_regs('I2C1Base', 	I2C1_BASE_OFS, I2C1_BASE,I2C1_BASE_LAST,0); end;
procedure I2C2_show_regs;begin 	show_regs('I2C2Base', 	I2C2_BASE_OFS, I2C2_BASE,I2C2_BASE_LAST,0); end;
procedure PWM_show_regs; begin 	show_regs('PWMBase', 	PWM_BASE_OFS,  PWM_BASE, PWM_BASE_LAST,0); end;
procedure STIM_show_regs;begin  show_regs('SYSTIMBase', STIM_BASE_OFS, STIM_BASE,STIM_BASE_LAST,0); end;
procedure TIM_show_regs; begin 	show_regs('TIMRBase', 	TIMR_BASE_OFS, TIMR_BASE,INTR_BASE_LAST,0); end;
procedure CLK_show_regs; begin 	show_regs('CLKBase', 	CLK_BASE_OFS,  GMGP0CTL, GMGP2DIV,0); writeln;
								show_regs('PWMCLK',  	CLK_BASE_OFS,  PWMCLKCTL,PWMCLKDIV,0); end;
procedure Q4_show_regs;  begin 	show_regs('Q4Base',  	BCM2709_LP_OFS,Q4LP_BASE,Q4LP_Last,2); end;

procedure Clock_show_regs;
begin
  show_regs('SPIClk',	SPI0_BASE_OFS,	SPI0_CLK,		SPI0_CLK,0,false); 		
  show_regs('I2C0Clk',	I2C0_BASE_OFS,	I2C0_DIV,		I2C0_DIV,0,false); 	
  show_regs('I2C1Clk',	I2C1_BASE_OFS,	I2C1_DIV,		I2C1_DIV,0,false); 	
  show_regs('I2C2Clk',	I2C2_BASE_OFS,	I2C2_DIV,		I2C2_DIV,0,false); 	
  show_regs('TIMR',		TIMR_BASE_OFS,	APMPreDivider,	APMPreDivider,0,false);
  show_regs('GMGPxCTL',	CLK_BASE_OFS,	GMGP0DIV,		GMGP0DIV,0,false); 
  show_regs('GMGPxCTL',	CLK_BASE_OFS,	GMGP1DIV,		GMGP1DIV,0,false); 	
  show_regs('GMGPxCTL',	CLK_BASE_OFS,	GMGP2DIV,		GMGP2DIV,0,false); 
  show_regs('PWMCLK',	CLK_BASE_OFS,	PWMCLKDIV,		PWMCLKDIV,0,false); 
  show_regs('Q4LP',		BCM2709_LP_OFS,	Q4LP_CTIMPRE,	Q4LP_CTIMPRE,2,false);  
end;

procedure GPIO_set_RESET(gpio:longword); 
var idx,mask:longword;
begin // RESET 3Bits @ according gpio location within register GPFSELn
  GPIO_get_mask_and_idx(GPFSEL,gpio,idx,mask);
  BCM_SETREG(idx,(not GPIO_get_ALTMask(gpio,INPUT)),true,true); 
end;
  
procedure GPIO_set_INPUT (gpio:longword); 
begin 
  GPIO_MSG_INFO(LOG_DEBUG,'GPIO_set_INPUT: ',gpio,INPUT); 
  GPIO_set_RESET(gpio);
end;

procedure GPIO_set_OUTPUT(gpio:longword); 
var idx,mask:longword;
begin 
  GPIO_MSG_INFO(LOG_DEBUG,'GPIO_set_OUTPUT: ',gpio,OUTPUT);
  GPIO_get_mask_and_idx(GPFSEL,gpio,idx,mask);
  GPIO_set_RESET(gpio); // Always use GPIO_set_RESET(x) before using GPIO_set_OUTPUT(x), to reset Bits
  BCM_SETREG(idx,GPIO_get_ALTMask(gpio,OUTPUT),false,true); 
end; 

procedure GPIO_set_ALT(gpio:longword; altfunc:t_port_flags);
var idx,mask:longword;
begin
  GPIO_MSG_INFO(LOG_DEBUG,'GPIO_set_ALT: ',gpio,altfunc);
  GPIO_get_mask_and_idx(GPFSEL,gpio,idx,mask);
  GPIO_set_RESET(gpio); // Always use GPIO_set_RESET(x) before using GPIO_set_ALT(x,y), to reset Bits
  BCM_SETREG(idx,GPIO_get_ALTMask(gpio,altfunc),false,true);
end;

function  RPI_ShutDown_Thread(ptr:pointer):ptrint;
(*	pushbutton connected to this GPIO pin, using GPIO3/HWPIN:5 (default) also has the benefit of
	wakeing / powering up Raspberry Pi when button is pressed *)
var buttonPressedTime:TDateTime; tog,noovrpres,TermThread:boolean; elapsedTime_msec:int64; sh,msg:string; 
begin
  Thread_SetName('RPIShutDown');
  tog:=false; noovrpres:=true; TermThread:=false; buttonPressedTime:=now;
  with RPI_ShutDown_struct do
  begin
    msg:='RPI_ShutDown[Pin#'+Num2Str(HWPin,0)+'/GPIO'+Num2Str(gpio,0)+']: Thread START debounce:'+Num2Str(RPI_ShutDownDebounce_ms,0)+'msec  ShutdownTime:'+Num2Str(RPI_ShutDownMin_ms,0)+'msec';
	SAY(LOG_WARNING,msg); 
	repeat
	  GPIO_Switch(RPI_ShutDown_struct);
	  if ein and noovrpres then
	  begin // OnOff-Button
//		if not tog then SAY(LOG_INFO,'+########################################################## '+Bool2Str(ein)+' '+Bool2Str(tog));
		if not tog
		  then begin tog:=true; buttonPressedTime:=now; end 
		  else noovrpres:=(MilliSecondsBetween(buttonPressedTime,now)<=(RPI_ShutDownMin_ms+RPI_ShutDownDebounce_ms));
	  end
	  else  
	  begin  
		if tog then
	  	begin
		  elapsedTime_msec:=MilliSecondsBetween(buttonPressedTime,now);
	  	  tog:=false;
	  	  msg:='RPI_ShutDown[Pin#'+Num2Str(HWPin,0)+'/GPIO'+Num2Str(gpio,0)+'/'+Num2Str(elapsedTime_msec,0)+'msec]:';
//	  	  SAY(LOG_INFO,'-########################################################## '+Bool2Str(ein)+' 0x'+Bool2Str(tog)+' '+Num2Str(RPI_ShutDownMin_ms,0)+' '+Num2Str(RPI_ShutDownDebounce_ms,0));
	  	  if (elapsedTime_msec<RPI_ShutDownMin_ms) then
	  	  begin
	  	 	if (elapsedTime_msec>RPI_ShutDownDebounce_ms) then 
	  	  	begin // button pressed for a shorter time, reboot
	  	  	  SAY(LOG_WARNING,msg+' rebooting requested'); 
	  	  	  if (RPI_ShutDown_RebootCall=nil) then
	  	  	  begin
	  	  	    terminateProg:=true;
	  	  	    delay_msec(10);	// let other Threads time to terminate
	  	  		call_external_prog(LOG_INFO,sudo+' shutdown -r now',sh); 
	  	  	  end else RPI_ShutDown_RebootCall;
	  	  	  TermThread:=true;
			end else SAY(LOG_WARNING,msg+' debounce');
	  	  end 
	  	  else 
	  	  begin // button pressed for more than specified time, shutdown
	  		SAY(LOG_WARNING,msg+' shutdown requested');
	  		if (RPI_ShutDown_Call=nil) then
	  		begin
	  		  terminateProg:=true;
	  		  delay_msec(10);	// let other Threads time to terminate
	  		  call_external_prog(LOG_INFO,sudo+' shutdown -h now',sh); 
	  		end else RPI_ShutDown_Call;
	  		TermThread:=true;
	  	  end;
//	  	  SAY(LOG_INFO,'');
	  	end; 
	  end;	// OnOff-Button
	  if ein then delay_msec(1) else delay_msec(10);
	until (TermThread or terminateProg);
  end; // with
  SAY(LOG_INFO,'RPI_ShutDown: Thread END');
  terminateProg:=true;
  EndThread;
  RPI_ShutDown_Thread:=0;
end;

function  RPI_ShutDownInit(hwpin:longint; shutdownMIN_msec,debounce_msec:word; 
				RebootCall,ShutDownCall:TProcedureNoArgCall; 
				desc:string; flags:s_port_flags):boolean;
var _ok:boolean;
begin
  _ok:=false;
  RPI_ShutDownMin_ms:=shutdownMIN_msec;
  RPI_ShutDownDebounce_ms:=debounce_msec;
  RPI_ShutDown_RebootCall:=	RebootCall;
  RPI_ShutDown_Call:=		ShutDownCall;
  if (hwpin>0) then
  begin
  	RPI_ShutDownGPIO:=GPIO_MAP_HDR_PIN_2_GPIO_NUM(hwpin);
  	if (RPI_ShutDownGPIO>=0) then
  	begin
	  _ok:=true;    
	  GPIO_SetStruct(RPI_ShutDown_struct,1,RPI_ShutDownGPIO,desc,flags);
	end;
  end;
  RPI_ShutDownInit:=_ok;
end;
function  RPI_ShutDownInit(hwpin:longint):boolean; 
begin 
  RPI_ShutDownInit:=RPI_ShutDownInit(hwpin,3100,7,nil,nil,'PIShutDown',[INPUT,PullUP,ReversePOLARITY]); 
end;

function  RPI_ShutDownStart:boolean; 
var _ok:boolean;
begin 
  _ok:=GPIO_Setup(RPI_ShutDown_struct);
  if _ok then BeginThread(@RPI_ShutDown_Thread,nil)
  		 else LOG_Writeln(LOG_ERROR,'RPI_ShutDownStart: can not GPIO_Setup'); 
  RPI_ShutDownStart:=_ok;
end;

function  pwm_SW_Thread(ptr:pointer):ptrint;
begin
  with GPIO_ptr(ptr)^ do
  begin
    if (gpio>=0) and (ptr<>nil) then
	begin	
      writeln('pwm_SW_Thread: Start of ',description,' with PWMSW (GPIO',Num2Str(gpio,0),')');
//	  , period(us):',PWM.pwm_period_us,' dtycycl(us):',PWM.pwm_dutycycle_us,' restcycl(us):',PWM.pwm_restcycle_us);
      Thread_SetName(description);
	  while not ThreadCtrl.TermThread do
	  begin			
	    if PWM.pwm_sigalt then
		begin
		  if (PWM.pwm_dutycycle_us>0)	then 
		  begin 
//          writeln('PWM.pwm_dutycycle_us:',PWM.pwm_dutycycle_us);
		    mmap_arr^[regset]:=mask_1Bit;
		    if (PWM.pwm_restcycle_us>0)	then delay_us(PWM.pwm_dutycycle_us)
										else PWM.pwm_sigalt:=false;
		  end;
	      if (PWM.pwm_restcycle_us>0)	then 
		  begin 
//          writeln('PWM.pwm_restcycle_us:',PWM.pwm_restcycle_us);
		    mmap_arr^[regclr]:=mask_1Bit; 
		    if (PWM.pwm_dutycycle_us>0)	then delay_us(PWM.pwm_restcycle_us)
										else PWM.pwm_sigalt:=false;
		  end;
		end
		else delay_msec(PWM.pwm_period_ms);
	  end; 
	  mmap_arr^[regclr]:=mask_1Bit; 
	end else LOG_Writeln(LOG_ERROR,'pwm_SW_Thread: GPIO not supported or no valid datastruct pointer');
    writeln('pwm_SW_Thread: END of ',description);
	EndThread;
  end;
  pwm_SW_Thread:=0;
end;

function  pwm_GetDCSWVal(pwm_period_us,pwm_value,pwm_dutyrange:longword):longword;
var pwm_dutycycle_us:longword;
begin
  pwm_dutycycle_us:=0;
  if (pwm_dutyrange>0) then pwm_dutycycle_us:=round(pwm_period_us*pwm_value/(pwm_dutyrange-1));
  pwm_GetDCSWVal:=pwm_dutycycle_us;
end;

function  pwm_GetMODVal(value,maxval:longword):longword;
var res:longword;
begin
  res:=value;
  if (res>=maxval) then if (maxval>0) then res:=(res mod maxval) else res:=0;
  pwm_GetMODVal:=res;
end;

function  PWM_GetDRVal(percent:real; dutyrange:longword):longword; 
//dutyrange: 	pwm_dutyrange
//percent: 		0-1
//output:		0-(pwm_dutyrange-1)
var res:longword;
begin
  res:=0;
  if ((dutyrange>0) and (percent>0) and (percent<=1)) then res:=round(percent*(dutyrange-1));
  PWM_GetDRVal:=res;
end;

procedure pwm_WriteRange(gpio,range:longword);
begin
  case gpio of 
    GPIO_PWM0,GPIO_PWM0A0: BCM_SETREG(PWM0RNG,range); // HW PWM
	GPIO_PWM1,GPIO_PWM1A0: BCM_SETREG(PWM1RNG,range); // HW PWM
  end; // case
end;

procedure pwm_Write(gpio,value:longword);
begin
  case gpio of  
    GPIO_PWM0,GPIO_PWM0A0: BCM_SETREG(PWM0DAT,value); // HW PWM
	GPIO_PWM1,GPIO_PWM1A0: BCM_SETREG(PWM1DAT,value); // HW PWM
  end; // case
end;

procedure pwm_Write(var GPIO_struct:GPIO_struct_t; value:longword); // value: 0-(pwm_dutyrange-1)
begin
  with GPIO_struct do
  begin
    PWM.pwm_value:=pwm_GetMODVal(value,PWM.pwm_dutyrange); //value: 0-(pwm_dutyrange-1)
	PWM.pwm_dutycycle_us:=pwm_GetDCSWVal(PWM.pwm_period_us,PWM.pwm_value,PWM.pwm_dutyrange);	
	PWM.pwm_restcycle_us:=0; 
	if PWM.pwm_period_us>PWM.pwm_dutycycle_us 
	  then PWM.pwm_restcycle_us:=PWM.pwm_period_us-PWM.pwm_dutycycle_us
	  else PWM.pwm_dutycycle_us:=PWM.pwm_period_us;
	PWM.pwm_period_ms:=trunc(PWM.pwm_period_us/1000); 
	if PWM.pwm_period_ms<=0 then PWM.pwm_period_ms:=1;
	PWM.pwm_sigalt:=true;
(*  writeln('pwm_Write:'+
		' GPIO'+Num2Str(gpio,0)+
		' value:'+Num2Str(PWM.pwm_value,0)+
		' dtyrange:'+Num2Str(PWM.pwm_dutyrange,0)+
		' dtyperiod(us):'+Num2Str(PWM.pwm_period_us,0)+
		' dtycycl(us):'+Num2Str(PWM.pwm_dutycycle_us,0)+
		' dtyrest(us):'+Num2Str(PWM.pwm_restcycle_us,0)
		);*)
    if (PWMHW IN portflags) then
	begin
      case gpio of	  
         GPIO_PWM0,GPIO_PWM0A0: BCM_SETREG(PWM0DAT,PWM.pwm_value,false,false); // HW PWM
	     GPIO_PWM1,GPIO_PWM1A0: BCM_SETREG(PWM1DAT,PWM.pwm_value,false,false); // HW PWM
      end; // case
	end;
  end; // with  
end; 

function  CLK_GetFreq(clksource:longword):real; // Hz
(*how to determine PLL freq:
http://blog.riyas.org/2014/01/raspberry-pi-as-simple-low-cost-rf-signal-generator-sweeper.html
http://raspberrypi.stackexchange.com/questions/1153/what-are-the-different-clock-sources-for-the-general-purpose-clocks
The clock frequencies were determined by experiment. 
The oscillator (19.2 MHz) and PLLD (500 MHz) are unlikely to change.
Clock sources
0     0 Hz     Ground
1     19.2 MHz oscillator
2     0 Hz     testdebug0
3     0 Hz     testdebug1
4     0 Hz     PLLA
5     1000 MHz PLLC (changes with overclock settings)
6     500 MHz  PLLD
7     216 MHz  HDMI auxiliary
8-15  0 Hz     Ground
The integer divider may be 2-4095. The fractional divider may be 0-4095.
There is (probably) no 25MHz cap for using non-zero mash values.
There are three general purpose clocks.
The clocks are named GPCLK0, GPCLK1, and GPCLK2.
Don't use GPCLK1 (it's probably used for the Ethernet clock). *)
var f:real;
begin
  case clksource of 
	 1 : f:= osc_freq_c;	// OSC  (19.2Mhz)	
	 5 : f:= pllc_freq_c;	// PLLC (1000Mhz changes with overclock settings) 
	 6 : f:= plld_freq_c;	// PLLD (500Mhz)
	 7 : f:= HDMI_freq_c;	// HDMI (216Mhz auxiliary)
	else f:= 0.0;
  end; // case
//writeln('CLK_GetFreq corefreq:',(pllc_freq):0:5);
  CLK_GetFreq:=f; 
end;

function  CLK_GetMinFreq:real; begin CLK_GetMinFreq:=CLK_GetFreq(1)/(4095.4095); end;
function  CLK_GetMaxFreq:real; begin CLK_GetMaxFreq:=CLK_GetFreq(6)/(1.0); end;
function  CLK_ValidFreq(freq_Hz:real):boolean;
begin CLK_ValidFreq:=((freq_Hz>=CLK_GetMinFreq) and (freq_Hz<=CLK_GetMaxFreq)); end;

function CLK_CheckFreq(freq_Hz:real; clksrc:longword; var divi,divf,mash:longword):boolean;
// !!todo!!, calc freq for mash>0
var _ok:boolean; da:real; mindivi:byte;
begin
  _ok:=CLK_ValidFreq(freq_Hz);  
  if _ok and (freq_Hz>0) then
  begin
    case mash of
	    3: begin mindivi:=5; end;
	    2: begin mindivi:=3; end;
	    1: begin mindivi:=2; end;
	  else begin mindivi:=1; mash:=0; end;
	end;
	if mash<>0 then LOG_Writeln(LOG_ERROR,'CLK_CheckFreq: currently not implemented mash<>0');
    da:=CLK_GetFreq(clksrc)/freq_Hz; 
	divi:=trunc(da); divf:=round(4096.0*(da-divi));
    _ok:=(not ((divi>4095.0) or (divi<mindivi) or (divf>4095.0)));
//	writeln('CLK_CheckFreq: freq(Hz):',freq_hz:0:2,' clksrc:',clksrc:0,' PLLfreq(Hz):',CLK_GetFreq(clksrc):0:1,' da:',da:0:2,' divi:',divi,' divf:',divf,' mash:',mash,' ok:',_ok);
  end;
  CLK_CheckFreq:=_ok;
end; 

function  CLK_GetSource(freq_Hz:real; var clksrc,divi,divf,mash:longword):boolean;
var _ok:boolean; 
begin
  _ok:=false; clksrc:=1; divi:=4095; divf:=4095;
  if CLK_ValidFreq(freq_Hz) then
  begin // find the best clk source // 6/1/7/5
    if (not _ok) then begin clksrc:=6; _ok:=CLK_CheckFreq(freq_Hz,clksrc,divi,divf,mash); end;
    if (not _ok) then begin clksrc:=1; _ok:=CLK_CheckFreq(freq_Hz,clksrc,divi,divf,mash); end;
	if (not _ok) then begin clksrc:=7; _ok:=CLK_CheckFreq(freq_Hz,clksrc,divi,divf,mash); end;
    if (not _ok) then begin clksrc:=5; _ok:=CLK_CheckFreq(freq_Hz,clksrc,divi,divf,mash); end;
  end;
  CLK_GetSource:=_ok;
end;  

function  CLK_GetRegIdx(mode:byte; var regctlidx,regdividx:longword):boolean;
var _ok:boolean;
begin
  _ok:=false;
  case mode of
    0 : begin _ok:=true; regctlidx:=GMGP0CTL;  regdividx:=GMGP0DIV;  end;
	1 : begin _ok:=true; regctlidx:=GMGP1CTL;  regdividx:=GMGP1DIV;  end;
	2 : begin _ok:=true; regctlidx:=GMGP2CTL;  regdividx:=GMGP2DIV;  end;
    3 : begin _ok:=true; regctlidx:=PWMCLKCTL; regdividx:=PWMCLKDIV; end;
  end; // case
  CLK_GetRegIdx:=_ok;
end;

function  CLK_GetDivisor(regcont:longword):real;
begin
  CLK_GetDivisor:=((regcont and $fff000) shr 12)+((regcont and $fff) shl 10); 
end;

function  CLK_GetMashValue(mode:byte):byte; 
var regctl,regdiv:longword;
begin
  CLK_GetRegIdx(mode,regctl,regdiv);
  CLK_GetMashValue:=byte((BCM_GETREG(regctl) and $600) shr 9); 
end;

function  CLK_GetClkFreq(mode:byte; PLL_FREQ,FREQ_req:real; 
                         var FREQ_O_min,FREQ_O_avg,FREQ_O_max:real;
						 var MASH:byte; var DIVIF:longword):boolean;
var DIVImin,DIVI,DIVF:longword; divisor:real; ok:boolean;
begin
  ok:=false;
  MASH:=CLK_GetMashValue(mode) and $3; // MashValue 0..3
  DIVImin:=MASH+1; if MASH=3 then DIVImin:=5;
  if abs(FREQ_req)<>0 then
  begin
    divisor:=PLL_FREQ/FREQ_req; 
	DIVI:=trunc(divisor) and $fff; DIVF:=round(frac(divisor)/1024) and $fff;	// 2x12Bit values
	if DIVI<DIVImin then DIVI:=DIVImin;
	DIVIF:=((DIVI shl 12) or DIVF);
//	writeln('divisor: ',divisor:0:5,' DIVImin:',DIVImin,' DIVI:',DIVI,' DIVF:',DIVF,' MASH:',MASH,' DIVIF:',DIVIF);
    case MASH of
      0 : begin 
		    FREQ_O_max:=PLL_FREQ/DIVI;
		    FREQ_O_avg:=PLL_FREQ/DIVI;
		    FREQ_O_min:=PLL_FREQ/DIVI;
		  end;
	  1 : begin 
		    FREQ_O_max:=PLL_FREQ/DIVI;
		    FREQ_O_avg:=PLL_FREQ/(DIVI+(DIVF shl 10));
		    FREQ_O_min:=PLL_FREQ/(DIVI+1);
		  end;
	  2 : begin 
		    FREQ_O_max:=PLL_FREQ/(DIVI-1);
		    FREQ_O_avg:=PLL_FREQ/(DIVI+(DIVF shl 10));
		    FREQ_O_min:=PLL_FREQ/(DIVI+2);
		  end;
	  3 : begin 
		    FREQ_O_max:=PLL_FREQ/(DIVI-3);
		    FREQ_O_avg:=PLL_FREQ/(DIVI+(DIVF shl 10));
		    FREQ_O_min:=PLL_FREQ/(DIVI+4);
		  end;
    end; // case
	ok:=(FREQ_O_max<=Clk_GetFreq(5));
  end;
  CLK_GetClkFreq:=ok;
end;

function  CLK_Write(regctlidx,regdividx:longword; DIVI,DIVF,ctlmask:longword):boolean;
const wt_us=1; maxtry=1000; CLK_CTL_ENAB=$00000010;
var n:longword; ok:boolean;
begin
  n:=0;
//writeln('CLK_Write: '+Num2Str(DIVI,0));  
  BCM_SETREG(regctlidx,BCM_PWD or $01,false,false); // stop clock										
  while ((BCM_GETREG(regctlidx) and $80)<>0) and (n<=maxtry) do	// Wait for clock to be !BUSY
    begin inc(n); delay_us(wt_us); end;
  ok:=(n<maxtry);
  if not ok then 
  begin
	LOG_Writeln(LOG_WARNING,'CLK_Write: take to long time to get ready '+Num2Str(n,0));
	delay_msec(1);
  end
  else if (n>100) then LOG_Writeln(LOG_WARNING,'CLK_Write: n:'+Num2Str(n,0));
  BCM_SETREG(regdividx,(BCM_PWD or ((DIVI and $0fff) shl 12) or (DIVF and $0fff)),false,false); // set clock divider						
  if ctlmask<>0 then
  begin
    delay_us(10);
    BCM_SETREG(regctlidx,(BCM_PWD or (ctlmask and (not CLK_CTL_ENAB))),false,false); 
  end;
  delay_us(10);  
  BCM_SETREG(regctlidx,(BCM_PWD or ctlmask or CLK_CTL_ENAB),false,false); // start clock
  CLK_Write:=ok;
end;

function  PWM_ClkWrite(regctlidx,regdividx:longword; DIVI:longword):boolean;
const wt_us=1; maxtry=1000; 
var pwm_control:longword; ok:boolean;
begin
//writeln('PWM_ClkWrite: '+Num2Str(DIVI,0));
  pwm_control:=BCM_GETREG(PWMCTL);				// save register content 
//writeln('PWMCTL: 0x',Hex(pwm_control,8));
  BCM_SETREG(PWMCTL,0,false,false);  			// stop PWM 
  ok:=CLK_Write(regctlidx,regdividx,DIVI,0,$01);// $01: clock src from osci
  BCM_SETREG(PWMCTL,pwm_control,false,false); 	// restore PWM_CONTROL	
  PWM_ClkWrite:=ok;
end;

function  PWM_GetMinFreq(dutycycle:longword):longword; 
var lw:longword; 
begin
  if dutycycle<>0 then lw:=round(CLK_GetFreq(1)/(PWM_DIVImax*dutycycle)) else lw:=0;
  PWM_GetMinFreq:=lw;
end;

function  PWM_GetMaxFreq(dutycycle:longword):longword;
var lw:longword;   
begin
  if dutycycle<>0 then lw:=round(CLK_GetFreq(1)/(PWM_DIVImin*dutycycle)) else lw:=0;
  PWM_GetMaxFreq:=lw;
end;

function  PWM_GetMaxDtyC(freq:real):longword;
var lw:longword;
begin
  if freq<>0 then lw:=round(CLK_GetFreq(1)/(PWM_DIVImin*freq)) else lw:=0;
  PWM_GetMaxDtyC:=lw;
end;

function  PWM_GetDtyRangeVal(var GPIO_struct:GPIO_struct_t; DutyCycle:real):longword;
// DutyCycle: 0..1
var dcr:real; drlw:longword;
begin
  dcr:=DutyCycle; if dcr<0 then dcr:=0.0; if dcr>1.0 then dcr:=1.0; 
  with GPIO_struct.PWM do
  begin
    if pwm_dutyrange>1 then drlw:=round(dcr*(pwm_dutyrange-1)) else drlw:=0;
  end; // with
  PWM_GetDtyRangeVal:=drlw;
end;

procedure pwm_SetClock(var GPIO_struct:GPIO_struct_t); 
// same clock for PWM0 and PWM1. Needs only to be set once
var DIVI:longword;
begin
  with GPIO_struct do
  begin
    if (PWMHW IN portflags) then
	begin
      DIVI:=PWM_DIVImin;  // default
      if ((PWM.pwm_freq_Hz*PWM.pwm_dutyrange)<>0) 
	    then DIVI:=round(CLK_GetFreq(1)/(PWM.pwm_freq_Hz*PWM.pwm_dutyrange)); 
//    writeln('pwm_SetClock0: ',CLK_GetFreq(1):0:5,' freq(Hz):',PWM.pwm_freq_Hz:0:5,' dty:',PWM.pwm_dutyrange:0,' DIVI:',DIVI);
	  if (DIVI<PWM_DIVImin) or (DIVI>PWM_DIVImax) then 
	  begin
	    LOG_Writeln(LOG_ERROR,'pwm_SetClock DIVI:'+Num2Str(DIVI,0)+' desired PWM-Freq. will not be reached. use smaller duty cycle');
	    if (DIVI<PWM_DIVImin) then DIVI:=PWM_DIVImin else DIVI:=PWM_DIVImax;
	  end;
//    writeln('pwm_SetClock1: ',DIVI);
	  PWM_ClkWrite(PWMCLKCTL,PWMCLKDIV,DIVI);	
	end;
  end; // with
end;
		
function  PortFlagsString(flgs:s_port_flags):string;
var j:t_port_flags; sh:string;
begin
  sh:=''; 
  for j IN flgs do 
    sh:=sh+GetEnumName(TypeInfo(t_port_flags),ord(t_port_flags(j)))+' ';
  PortFlagsString:=sh;
end;
		
procedure GPIO_ShowStruct(var GPIO_struct:GPIO_struct_t);
begin
  with GPIO_struct do
  begin 
    writeln('GPIO_ShowStruct: ',description,' Portflags:',PortFlagsString(portflags),' initok:',initok,' Simulation:',simulation);
	writeln('HWPin:',HWPin,' GPIO',gpio:0,' nr:',nr:0,' State:',ein);
	writeln('idxofs_1Bit:0x',Hex(idxofs_1Bit,2),' mask_1Bit:0x',Hex(mask_1Bit,8),' idxofs_3Bit:0x',Hex(idxofs_3Bit,2),' mask_3Bit:0x',Hex(mask_3Bit,8));
	writeln('pwm_mode:',PWM.pwm_mode,' pwm_freq:',PWM.pwm_freq_hz:0:2,' pwm_dutyrange:',PWM.pwm_dutyrange,' value:',PWM.pwm_value,
	       ' pwm_dutycycle_us:',PWM.pwm_dutycycle_us,' pwm_period_us:',PWM.pwm_period_us);
  end;
end;

procedure  Thread_SetName(name:string);
const PR_SET_NAME=$0f;
var   thread_name:string[16];
begin
  thread_name:=copy(name+#$00,1,16); 
  if thread_name<>'' then
  begin
    {$IFDEF LINUX}
      if FpPrCtl(PR_SET_NAME,@thread_name[1],nil,nil,nil)<>0 then
        LOG_Writeln(LOG_ERROR,'Thread_SetName: can not set name '+name);  
    {$ENDIF}
  end;
end;

procedure Thread_ShowStruct(var ThreadCtrl:Thread_Ctrl_t);
var n:longint; sh:string;
begin
  with ThreadCtrl do
  begin 
    SAY(LOG_INFO,'');
	SAY(LOG_INFO,'ThreadInfo:        '+ThreadInfo);
//	SAY(LOG_INFO,'ThreadID:          ',TThreadID);
	SAY(LOG_INFO,'ThreadRunning:     '+Bool2Str(ThreadRunning)+' TermThread: '+Bool2Str(TermThread));
	SAY(LOG_INFO,'ThreadFunc:      0x'+Hex(ThreadFunc,16));
	SAY(LOG_INFO,'ThreadTimeOut:     '+FormatDateTime('YYYYMMDD hh:mm:ss.zzz',ThreadTimeOut));
	SAY(LOG_INFO,'ThreadCmdStr:      '+ThreadCmdStr);
	SAY(LOG_INFO,'ThreadRetStr:      '+ThreadRetStr);
	SAY(LOG_INFO,'ThreadRetCode:     '+Num2Str(ThreadRetCode,0));
	SAY(LOG_INFO,'ThreadProgressOld: '+Num2Str(ThreadProgressOld,0));
	SAY(LOG_INFO,'ThreadProgress:    '+Num2Str(ThreadProgress,0));
	sh:='UsrData[0-4]:      '; for n:=0 to 4 do sh:=sh+Num2Str(UsrData[n],0)+' ';  SAY(LOG_INFO,sh);
	sh:='ThreadPara[0-4]:   '; for n:=0 to 4 do sh:=sh+Num2Str(ThreadPara[n],0)+' ';  SAY(LOG_INFO,sh);
	sh:='ThreadParaStr[0-4]:'; for n:=0 to 4 do sh:=sh+ThreadParaStr[n]+' ';  SAY(LOG_INFO,sh);
	SAY(LOG_INFO,'');
  end;
end;

procedure Thread_InitStruct(var ThreadCtrl:Thread_Ctrl_t);
begin
  with ThreadCtrl do
  begin
    TermThread:=true; 	ThreadRunning:=false; ThreadRetCode:=0; 
    ThreadRetStr:='';	ThreadInfo:='';
    ThreadProgress:=0; 	ThreadProgressOld:=-maxint; ThreadTimeOut:=now; 
    ThreadID:=TThreadID(0);
  end; // with
end;

procedure Thread_InitStruct2(var ThreadCtrl:Thread_Ctrl_t; ThFunc:TThFunctionOneArgCall);
var n:longint;
begin
  with ThreadCtrl do 
  begin
	ThreadFunc:=ThFunc;
  	ThreadCmdStr:='';
  	for n:=0 to 4 do
  	begin
  	  ThreadPara[n]:=0; UsrData[n]:=0; ThreadParaStr[n]:='';
  	end;
  end; // with
end;

procedure Thread_InitStruct0(var ThreadCtrl:Thread_Ctrl_t);
begin
  Thread_InitStruct (ThreadCtrl);
  Thread_InitStruct2(ThreadCtrl,nil);
end;

function  Thread_Start(var ThreadCtrl:Thread_Ctrl_t; funcadr:TThreadFunc; 
					   paraadr:pointer; delaymsec:longword; prio:longint):boolean;
begin
  with ThreadCtrl do
  begin
	Thread_InitStruct(ThreadCtrl); TermThread:=false; 
	ThreadID:=BeginThread(funcadr,paraadr);
	ThreadRunning:=(ThreadID<>TThreadID(0));
	if ThreadRunning and (delaymsec>0) then delay_msec(delaymsec); // let thread time to start
	if ThreadRunning and (prio<>0) then ThreadSetPriority(ThreadID,prio);
	if ThreadRunning then SetTimeOut(ThreadTimeOut,15000); 
	Thread_Start:=ThreadRunning;
  end;
end;

function  Thread_End(var ThreadCtrl:Thread_Ctrl_t; waitmsec:longword):boolean;
begin
  with ThreadCtrl do
  begin
    TermThread:=true;
//  if ThreadRunning then ThreadRunning:=(WaitForThreadTerminate(ThreadID,waitmsec)=0); // does not work on raspian
	delay_msec(waitmsec); if ThreadRunning then ThreadRunning:=(not (KillThread(ThreadID)=0));
	Thread_InitStruct(ThreadCtrl); 
	Thread_End:=ThreadRunning;
  end;
end;

procedure HDMI_Switch(ein:boolean);
var sh:string;
begin
  sh:='tvservice '; if ein then sh:=sh+'-p' else sh:=sh+'-o';
  call_external_prog(LOG_NONE,sh,sh);
end;

procedure PWM_End(var GPIO_struct:GPIO_struct_t);
var regsav:longword;
begin 
  with GPIO_struct do
  begin
    ThreadCtrl.TermThread:=true; 
    if (PWMHW IN portflags) then
	begin // HW PWM	
      if GPIO_HWPWM_capable(gpio) then
	  begin 
		regsav:=BCM_GETREG(PWMCTL);			// save ctl register
//      writeln('PWM_End: PWMCTL 0x',hex(regsav,8));			
		if GPIO_HWPWM_capable(gpio,0) // // maskout Bits for channel1/2
		  then regsav:=(regsav and $0000ff00) and (not PWM0_ENABLE)
		  else regsav:=(regsav and $000000ff) and (not PWM1_ENABLE); 	
//      writeln('PWM_End: PWMCTL 0x',hex(regsav,8));
		BCM_SETREG(PWMCTL,regsav,false,false); // Disable channel PWM
	  end;
    end
	else Thread_End(ThreadCtrl,100);
  end;  // with
end;

procedure pwm_SetStruct(var GPIO_struct:GPIO_struct_t; mode:byte; freq_Hz:real; dutyrange,startval:longword);
begin
  with GPIO_struct do
  begin
  	PWM.pwm_mode:=mode; PWM.pwm_freq_hz:=freq_Hz; 
	with ThreadCtrl do begin TermThread:=true; ThreadRunning:=false; ThreadID:=TThreadID(0); end;
	if (PWM.pwm_freq_hz<>0) then PWM.pwm_period_us:=round(1000000/PWM.pwm_freq_hz) else PWM.pwm_period_us:=0; 
	PWM.pwm_dutyrange:=dutyrange; pwm_Write(GPIO_struct,startval);
(*	PWM.pwm_value:=startval; 
	PWM.pwm_dutycycle_us:=pwm_GetDCSWVal(PWM.pwm_period_us,PWM.pwm_value,PWM.pwm_dutyrange);
    if PWM.pwm_period_us>PWM.pwm_dutycycle_us 
	  then PWM.pwm_restcycle_us:=PWM.pwm_period_us-PWM.pwm_dutycycle_us
	  else PWM.pwm_dutycycle_us:=PWM.pwm_period_us;
	PWM.pwm_period_ms:=trunc(PWM.pwm_period_us/1000); 
	if PWM.pwm_period_ms<=0 then PWM.pwm_period_ms:=1;*)
  end;
end;

procedure pwm_SetStruct(var GPIO_struct:GPIO_struct_t); 
//HW-PWM: Mark Space mode // set pwm hw clock div to 32 (19.2Mhz/32 = 600kHz) // Default range of 1024
//SW-PWM: Mark Space mode // set pwm sw clock to 50Hz // DutyCycle range of 1000 (0-999)
const dcycl=1000;
begin 
  with GPIO_struct do
  begin
    if (PWMHW IN portflags)   
	  then pwm_SetStruct(GPIO_struct,PWM_MS_MODE,PWM_GetMaxFreq(dcycl),dcycl,0)  // set default values for HW PWM0/1
	  else pwm_SetStruct(GPIO_struct,PWM_MS_MODE, 				   50, dcycl,0); // SW PWM 50Hz; DutyCycle 0-999
  end;
end;

function  pwm_Setup(var GPIO_struct:GPIO_struct_t):boolean;
var regsav:longword;
begin
  with GPIO_struct do
  begin
    if initok and (OUTPUT IN portflags) then 
	begin
	  initok:=false; 
	  if (PWMHW IN portflags) then
	  begin // HW PWM	  
	    case gpio of
	      GPIO_PWM0,GPIO_PWM0A0,GPIO_PWM1A0,
		  GPIO_PWM1 : begin // PWM0:Pin12:GPIO18 PWM1:Pin35:GPIO19 
					    initok:=true; 
//				    	writeln('pwm_Setup (HW):'); GPIO_ShowStruct(GPIO_struct);
					    GPIO_set_PINMODE(gpio,PWMHW);					  
						regsav:=BCM_GETREG(PWMCTL);			// save ctl register
						BCM_SETREG(PWMCTL,0,false,false);  	// stop PWM 
					    pwm_SetClock      (GPIO_struct); 	// set clock external before pwm_Setup
//                      writeln('pwm_Setup: PWMCTL 0x',hex(regsav,8));			
//  					writeln('pwm_Setup: pwm_dutyrange ',PWM.pwm_dutyrange);
						if GPIO_HWPWM_capable(gpio,0) then
						begin
						  BCM_SETREG(PWM0RNG,PWM.pwm_dutyrange,false,false); delay_us(10); // set max value for duty cycle	
						  regsav:=regsav and $0000ff00;	// maskout Bits for channel1
						  regsav:=regsav or PWM0_ENABLE; 						  
						  if ((PWM.pwm_mode and PWM_MS_MODE)<>0)    then regsav:=regsav or PWM0_MS_MODE;
						  if ((PWM.pwm_mode and PWM_USEFIFO)<>0) 	then regsav:=regsav or PWM0_USEFIFO;	
						  if ((PWM.pwm_mode and PWM_POLARITY)<>0)	then regsav:=regsav or PWM0_REVPOLAR;	
						  if ((PWM.pwm_mode and PWM_RPTL)<>0) 	    then regsav:=regsav or PWM0_REPEATFF;			
						  if ((PWM.pwm_mode and PWM_SERIALIZER)<>0) then regsav:=regsav or PWM0_SERIAL;		  
						end
						else
						begin
						  BCM_SETREG(PWM1RNG,PWM.pwm_dutyrange,false,false); delay_us(10);
						  regsav:=regsav and $000000ff; // maskout Bits for channel2
						  regsav:=regsav or PWM1_ENABLE; 
						  if ((PWM.pwm_mode and PWM_MS_MODE)<>0)    then regsav:=regsav or PWM1_MS_MODE;
						  if ((PWM.pwm_mode and PWM_USEFIFO)<>0)    then regsav:=regsav or PWM1_USEFIFO;	
						  if ((PWM.pwm_mode and PWM_POLARITY)<>0)	then regsav:=regsav or PWM1_REVPOLAR;	
						  if ((PWM.pwm_mode and PWM_RPTL)<>0) 	    then regsav:=regsav or PWM1_REPEATFF;			
						  if ((PWM.pwm_mode and PWM_SERIALIZER)<>0) then regsav:=regsav or PWM1_SERIAL;		
						end;
//                      writeln('pwm_Setup: pwm_value ',PWM.pwm_value);
						pwm_Write  (GPIO_struct,PWM.pwm_value);	// set start value
//                      writeln('pwm_Setup: PWMCTL 0x',hex(regsav,8));			// 					
					    BCM_SETREG(PWMCTL,regsav,false,false);		// Enable channel PWM
					  end;
		  else Log_Writeln(LOG_ERROR,'pwm_Setup: GPIO'+Num2Str(gpio,0)+' not supported for HW PWM'); 
		end;
	  end
	  else
	  begin // SW PWM
        case gpio of
		  -999..-1: Log_Writeln(LOG_ERROR,'pwm_Setup: GPIO'+Num2Str(gpio,0)+' not supported for PWM'); 
		  else		begin 
		              if (gpio>=0) and (PWMSW IN portflags) then
					  begin
					    initok:=true;
						GPIO_set_PINMODE(gpio,OUTPUT); portflags:=portflags+[OUTPUT];
//                      writeln('pwm_Setup (SW):'); GPIO_ShowStruct(GPIO_struct);
// Start SW PWM Thread
					    Thread_Start(ThreadCtrl,@pwm_SW_Thread,addr(GPIO_struct),100,-1);
(*					    with ThreadCtrl do
						begin
						  TermThread:=false; ThreadRunning:=true; // Start SW PWM Thread
					      ThreadID:=BeginThread(@pwm_SW_Thread,addr(GPIO_struct)); 
						end;
						delay_msec(100); // let SW-Threads start
*)
					  end
					  else Log_Writeln(LOG_ERROR,'pwm_Setup: wrong neg. GPIO Error Code: '+Num2Str(gpio,0)+' '+PortFlagsString(portflags));
					end;
	    end; // case
	  end;
    end
	else Log_Writeln(LOG_ERROR,'pwm_Setup: GPIO_struct is not initialized'); 
  end;
  pwm_Setup:=GPIO_struct.initok;
end;

function  TIM_Setup(timr_freq_Hz:real):real;
var _ok:boolean; _divi:longword; _f:real;
begin
  _ok:=false; _f:=0;
  if timr_freq_Hz>0 then
  begin
    _divi:=round(CLK_GetFreq(5)/timr_freq_Hz); //250MHz CoreFreq/timr_freq_Hz
	if (_divi>0) and (_divi<=$400) then 
	begin
	  _f:=CLK_GetFreq(5)/_divi;
	  dec(_divi); _ok:=true; // the timer divide (10Bit) is base clock / (divide+1)
	  BCM_SETREG(APMPreDivider,_divi);
	  BCM_SETREG(APMCTL, 		$280);	// Free running counter Enabled; Timer enable
	end;
  end;
  if not _ok then 
    LOG_Writeln(LOG_ERROR,'TIM_Setup: can not set freq: '+Num2Str(timr_freq_Hz,0,0));
  TIM_Setup:=_f;
end;

procedure TIM_Test; // 1MHz
begin
  TIM_Setup(1000000); 
end;

function  OSC_Setup(_gpio:longint; pwm_freq_Hz,pwm_dty:real):longint;
var flgh:s_port_flags; gpio_struct:GPIO_struct_t;  
    pwm_dutyrange,_dtyw:longint;
begin
  if GPIO_FCTOK(_gpio,[PWMHW]) then flgh:=[PWMHW] else flgh:=[PWMSW];
  if pwm_dty<0 then pwm_dty:=0; if pwm_dty>1 then pwm_dty:=1; 
  if ((PWMSW IN flgh) and (pwm_freq_Hz>200)) then pwm_freq_Hz:=200;
  pwm_dutyrange:=PWM_GetMaxDtyC(pwm_freq_Hz); _dtyw:=round(pwm_dutyrange*pwm_dty);
  writeln('OSC_Setup: ',(PWMHW IN flgh),' f:',pwm_freq_Hz:0:1,'Hz range:',pwm_dutyrange:0,' dty:',_dtyw:0);
  GPIO_SetStruct (gpio_struct,1,_gpio,'OSC',[OUTPUT]+flgh);
  pwm_SetStruct  (gpio_struct,PWM_MS_MODE,pwm_freq_Hz,pwm_dutyrange,_dtyw); 
  pwm_SetClock   (gpio_struct);
  if not GPIO_Setup(gpio_struct) then pwm_dutyrange:=-1;
  OSC_Setup:=pwm_dutyrange;
end;

procedure OSC_Write(_gpio,pwm_dutyrange:longint; pwm_dty:real);
begin
  if pwm_dutyrange>0 then
  begin
    if pwm_dty<0 then pwm_dty:=0; if pwm_dty>1 then pwm_dty:=1; 
    pwm_write(_gpio,round(pwm_dty*(pwm_dutyrange-1)));
  end else LOG_Writeln(LOG_ERROR,'OSC_Write: invalid pwm_dutyrange '+Num2Str(pwm_dutyrange,0));
end;
	
procedure FREQ_CounterReset(var FREQ_Struct:FREQ_Determine_t);
begin
  with FREQ_Struct do begin fcnt:=0; fcntold:=0; fTurnRate_Hz:=0; fdet_enab:=false; end;
end;

procedure FREQ_InitStruct(var FREQ_Struct:FREQ_Determine_t; detint_ms:longint);
begin
  with FREQ_Struct do
  begin
	fSyncTime:=now;		fdet_ms:=detint_ms; fdet_enab:=false;
	FREQ_CounterReset(	FREQ_Struct);
  end; // with
end;

procedure FREQ_DetTurnRate(var FREQ_Struct:FREQ_Determine_t; steps:longint); 
var ms:longint; 
begin
  with FREQ_Struct do
  begin  
	fcnt:=fcnt+steps;
  	if TimeElapsed(fSyncTime,fdet_ms) then 
	begin
	  if fdet_enab then
	  begin
	  	ms:=MilliSecondsBetween(now,fSyncTime); 
	  	if (ms<>0) then 
	  	begin
		  fTurnRate_Hz:=((fcnt-fcntold)*1000/ms); fcntold:=fcnt;
		  if (fTurnRate_Hz=0) then FREQ_CounterReset(FREQ_Struct);	// new SF 22.5.2018
		end;   
	  end
	  else
	  begin
	  	FREQ_CounterReset(FREQ_Struct);
	    fdet_enab:=true; // prepare fdet on next step update
	  end;
    end;
  end; // with
end;

function  WAVE_InitArray(wavelist:TStringList; var wa:WAVE_Array_t; var valmin,valmax:real):longint;
//IN:	 StringList which has a number in each line
//OUT: 	 filled Array, min,max value
//Result:ArrayCount 
var res,n:longint; r:real;
begin
  res:=0; valmin:=maxreal; valmax:=-maxreal; 
  SetLength(wa,wavelist.count);
  for n:=1 to wavelist.count do
  begin
	if Str2Num(Trimme(wavelist[n-1],3),r) then
	begin
	  wa[res]:=r;
	  if r<valmin then valmin:=r;
	  if r>valmax then valmax:=r;
	  inc(res);
	end;
  end;
  if res<>Length(wa) then SetLength(wa,res); 
  WAVE_InitArray:=res;
end;

function  WAVE_InitArray(var wa:WAVE_Array_t; wavemode:WAVE_RampShape_t; valstart,valend:real; valcnt:longint; dtycycle:real):longint;
const k=1.0; Scnt=21; 
var ok:boolean; res,n,siglow,sighig:longint; delta,x,x0:real;
begin
  ok:=false; 
  if valcnt>0 then
  begin
	SetLength(wa,valcnt); delta:=0;
	if (not ok) and (wavemode IN [LIN_Ramp,LIN_Triangle,LIN_SawTooth]) then
	begin
	  ok:=true;
      if (valcnt>1) then delta:=(valend-valstart)/(valcnt-1);
      wa[valcnt-1]:=valend; wa[0]:=valstart; 
      for n:=1 to (valcnt-2) do wa[n]:=wa[n-1]+delta;
	end;
	
	if (not ok) and (wavemode IN [SINusoidal]) then
	begin
	  ok:=true;
	  if (valcnt>0) then delta:=(2*pi)/(valcnt-0);	// prevent 2x same value (0)
	  for n:= 0 to (valcnt-1) do wa[n]:=(valend-valstart)*(sin(n*delta))+valstart;
	end;
	
	if (not ok) and (wavemode IN [LIN_Square]) then
	begin
	  if (dtycycle<0) or (dtycycle>1) then dtycycle:=0.5;	// 0-100% default 50%
	  sighig:=round(valcnt*dtycycle);
	  siglow:=valcnt-sighig;
	  ok:=((sighig>0) or (siglow>0));
	  if ok then
	  begin
	    for n:= 1 to siglow do wa[n-1]:=valstart;
	    for n:= siglow to (valcnt-1) do wa[n]:=valend;
	  end;
	end;
	
	if (not ok) and (wavemode IN [S_Shape]) then
	begin // https://en.wikipedia.org/wiki/Logistic_function
	  if (valcnt>0) then
	  begin
	  	ok:=true; x0:=(valcnt-1)/2; x:=0; 
	  	delta:=Scnt/valcnt;
	  	for n:= 0 to (valcnt-1) do 
	  	begin
	  	  wa[n]:=1/(1+exp(-k*(x-x0)));
	  	  if n=0 			then wa[n]:=0.0;
	  	  if n>=(valcnt-1)	then wa[n]:=1.0;
		  wa[n]:=(valend-valstart) * wa[n] + valstart;
		  x:=x+delta;
	  	end;
	  end;
	end;
	
(*	if (not ok) and (wavemode IN [S_Shape]) then
	begin // http://www.pmean.com/04/scurve.html	// old approach
	  if (valcnt>0) then
	  begin
	  	ok:=true; x:=-10; 
	  	delta:=abs(x*2.0)/valcnt;
	  	for n:= 0 to (valcnt-1) do 
	  	begin
		  wa[n]:=(valend-valstart) * roundto(1.0/(1.0+exp(-k*x)),4) + valstart;
		  x:=x+delta;
	  	end;
	  end;
	end; *)
	
	if not ok then for n:=1 to valcnt do wa[n-1]:=valstart; 
  end else SetLength(wa,0);
  res:=Length(wa); if not ok then res:=-1;
  WAVE_InitArray:=res;
end;

function  WAVE_SetIdx(var wstruct:WAVE_Signal_Struct_t; var wa:WAVE_Array_t; startidx:longint):boolean;
var ok:boolean;
begin
  ok:=false;
  with wstruct do
  begin
    idx:=startidx;
    ok:=((idx>=0) and (idx<Length(wa))); 
	if up then dec(idx) else inc(idx);
  end;
  WAVE_SetIdx:=ok;
end;

procedure WAVE_Enable(var wstruct:WAVE_Signal_Struct_t; enab:boolean); begin wstruct.enable:=enab; end;
procedure WAVE_InitStruct(var wstruct:WAVE_Signal_Struct_t; var wa:WAVE_Array_t; wavemode:WAVE_RampShape_t; intervall_ms:longint);
begin
  with wstruct do
  begin
	timer:=now;
	int_ms:=intervall_ms;
	mode:=wavemode;
	enable:=false;
	up:=true;
//	if not WAVE_SetIdx(wstruct,wa,0) then LOG_Writeln(LOG_ERROR,'WAVE_IniStruct: startidx vs. size of WAVE_Array');
  end;
end;

procedure WAVE_Show(var wstruct:WAVE_Signal_Struct_t; var wa:WAVE_Array_t);
var n:longint;
begin
  writeln;
  with wstruct do
  begin
	writeln('WAVE_Show:');
	writeln('mode:',GetEnumName(TypeInfo(WAVE_RampShape_t),ord(mode)),' interval:',int_ms:0,' enable:',enable,' up:',up,' nextidx:',idx+1);  
  end; // with
  for n:=1 to Length(wa) do writeln((n-1):3,' ',wa[n-1]:7:3);
  writeln;
end;

//(LIN_Ramp,LIN_Triangle,LIN_SawTooth,LIN_Square,SINusoidal);
function  WAVE_GetIdx(var wstruct:WAVE_Signal_Struct_t; var wa:WAVE_Array_t):boolean;
var ok:boolean;
begin
  ok:=true;
  with wstruct do
  begin
	if (Length(wa)>=1) and enable then
	begin
	  if up then 
	  begin // direction up: idx will increase
		inc(idx);
		if idx>=length(wa) then
		begin
		  case mode of
			LIN_Ramp:		begin idx:=Length(wa)-1; end;	// remain at highest idx
			LIN_Triangle:	begin  // symmetric linear waveform, change up/down direction 
							  if idx>=2 then idx:=Length(wa)-2 else idx:=0; up:=false; 
							end;
	  	 	else			begin idx:=0; end;				// start again from 1. indx
		  end; // case
		end;
	  end
	  else
	  begin // direction down: idx will decrease
		dec(idx);
		if idx<=0 then begin up:=true; idx:=0; end;
	  end;
	  SetTimeOut(timer,int_ms);
	end else ok:=false;
  end; // with
  WAVE_GetIdx:=ok;
end;

procedure WAVE_Test;
const iv_ms=500; valcnt=8; dty=0.5; valstart=0; valend=1; startidx=0;
var n,j:longint; wstruct:WAVE_Signal_Struct_t; wa:WAVE_Array_t; 
begin
  for j:= ord(low(WAVE_RampShape_t)) to ord(high(WAVE_RampShape_t)) do
  begin // test all wave shapes
// useful valcnt to S_Shape: 21
	write('WAVE_Test: '+GetEnumName(TypeInfo(WAVE_RampShape_t),j)+' '+
						'valcnt:'+	Num2Str(valcnt,0)+' '+
						'valstart:'+Num2Str(valstart,0,3)+' '+
						'valend:'+	Num2Str(valend,0,3)+' '+
						'idxstart:'+Num2Str(startidx,0)+' '+
						'interval:'+Num2Str(iv_ms,0)+'ms'
		);
	if j=ord(LIN_Square) then write(' DtyCycle:'+Num2Str(dty*100,0,0)+'%');
	writeln; 
  	if WAVE_InitArray(wa,WAVE_RampShape_t(j),valstart,valend,valcnt,dty)>0 then
	begin
	  WAVE_InitStruct(wstruct,wa,WAVE_RampShape_t(j),iv_ms);
	  WAVE_SetIdx	 (wstruct,wa,0);
	  WAVE_Enable	 (wstruct,true);
	  n:=0;
	  while (n<=(2*valcnt-1)) do
	  begin	// 2 full cycles
		with wstruct do 
		begin
		  if TimeElapsed(timer) then
		  begin // every 'iv_ms' a new idx to address wa[idx]
			if enable and WAVE_GetIdx(wstruct,wa)
			  then writeln('WAVE_Test['+Num2Str(n,2)+']: '+Num2Str(wa[idx],6,3))
			  else LOG_Writeln(LOG_ERROR,'WAVE_Test: #2');
			inc(n);
		  end else sleep(10); 
		end; // with
	  end; // while
	
	end else LOG_Writeln(LOG_ERROR,'WAVE_Test: #1');  
	writeln;
  end; // for
  SetLength(wa,0);
end;

procedure FRQ_Switch(var GPIO_struct:GPIO_struct_t; ein:boolean);
var regsav:longword;
begin 
  with GPIO_struct do
  begin
	if ein then
	begin // freq on
	  Log_Writeln(Log_ERROR,'FRQ_ON: currently not implemented');	/// !!!!! TODO !!!!!
//	  ThreadCtrl.TermThread:=true; 
	  if (FRQHW IN portflags) then
	  begin 	
//		regsav:=(BCM_GETREG(FRQ_CTLIdx) and $70f); // mask out Enable and unused Bits
//		BCM_SETREG(FRQ_CTLIdx,(BCM_PWD or regsav),false,false); 	// Disable clock 
	  end;	
	end
	else
	begin // freq off
	  ThreadCtrl.TermThread:=true; 
	  if (FRQHW IN portflags) then
	  begin 	
    	regsav:=(BCM_GETREG(FRQ_CTLIdx) and $70f); // mask out Enable and unused Bits
		BCM_SETREG(FRQ_CTLIdx,(BCM_PWD or regsav),false,false); 	// Disable clock 
	  end;
    end;
  end;  // with
end;

function  FRQ_GetClkRegIdx(gpio:longint; var mode:byte):boolean;
var _ok:boolean;
begin
  _ok:=true; mode:=$ff;
  case gpio of // set clocksource
    GPIO_FRQ04_CLK0,GPIO_FRQ20_CLK0,
	GPIO_FRQ32_CLK0,GPIO_FRQ34_CLK0: mode:=0;
	GPIO_FRQ05_CLK1,GPIO_FRQ21_CLK1,
	GPIO_FRQ42_CLK1,GPIO_FRQ44_CLK1: mode:=1;
    GPIO_FRQ06_CLK2,GPIO_FRQ43_CLK2: mode:=2;
    else _ok:=false; 
  end; // case	
  if not _ok then LOG_Writeln(LOG_ERROR,'FRQ_GetClkRegIdx: no clock GPIO'+Num2Str(gpio,0));
  FRQ_GetClkRegIdx:=_ok;
end;

function  FRQ_Setup(var GPIO_struct:GPIO_struct_t; freq_Hz:real):boolean;
var _mode:byte; _clksrc,_msk,_divi,_divf,_mash:longword; 
begin
  with GPIO_struct do
  begin
    initok:=CLK_ValidFreq(freq_Hz);
    if initok and (FRQHW IN portflags) then 
	begin
	  FRQ_freq_Hz:=freq_Hz; _mash:=0;
	  initok:=CLK_GetSource(FRQ_freq_Hz,_clksrc,_divi,_divf,_mash); 
	  if initok then
	  begin	  	  
//writeln('FRQ_Setup: freq(Hz):',FRQ_freq_Hz:0:2,' divi:0x',Hex(_divi,3),' divf:0x',Hex(_divf,3),' clksrc:',_clksrc:0,' mash:',_mash:0);
	    initok:=FRQ_GetClkRegIdx(gpio,_mode); 	
        if initok then initok:=CLK_GetRegIdx(_mode,FRQ_CTLIdx,FRQ_DIVIdx);  		
		if initok then
        begin	
		  initok:=false; 
          if (ALT0 IN portflags) then begin GPIO_set_ALT(gpio,ALT0); initok:=true; end;
		  if (ALT1 IN portflags) then begin GPIO_set_ALT(gpio,ALT1); initok:=true; end;
		  if (ALT2 IN portflags) then begin GPIO_set_ALT(gpio,ALT2); initok:=true; end; 
		  if (ALT3 IN portflags) then begin GPIO_set_ALT(gpio,ALT3); initok:=true; end; 
		  if (ALT4 IN portflags) then begin GPIO_set_ALT(gpio,ALT4); initok:=true; end; 
		  if (ALT5 IN portflags) then begin GPIO_set_ALT(gpio,ALT5); initok:=true; end; 
          if not initok then LOG_Writeln(LOG_ERROR,'FRQ_Setup: ALTx');		  
          _msk:=((_mash and $3) shl 9) or (_clksrc and $0f); // set mash and clk-src	  
		  if initok then initok:=CLK_Write(FRQ_CTLIdx,FRQ_DIVIdx,_divi,_divf,_msk);
//        writeln('Mash:0x',Hex(CLK_GetMashValue(_mode),2),' mode:',_mode,' clksrc:',_clksrc);
		  if not initok then LOG_Writeln(LOG_ERROR,'FRQ_Setup: CLK_Write');		  
        end else LOG_Writeln(LOG_ERROR,'FRQ_Setup: CLK_GetRegIdx');					
	  end else LOG_Writeln(LOG_ERROR,'FRQ_Setup: CLK_GetSource');	
	end else LOG_Writeln(LOG_ERROR,'FRQ_Setup for freq(Hz): '+Num2Str(FRQ_freq_Hz,0,2)+' not possible');
    FRQ_Setup:=initok;
  end; // with
end;

procedure FRQ_WaveTest; // !!!! not completed !!!!!
const gpio=4; maxcnt=50; scal=100; freqHz=100000;
type t_MM = array of longword; 
var  GPIO_struct:GPIO_struct_t; range:t_MM; n:longword;
  procedure FillWaveTable;
  var step:real; i:longword;
  begin
    step:=(2*pi)/maxcnt;
    for i:= 0 to (maxcnt-1) do range[i]:=round(scal*(sin(i*step)+1));
  end;
begin 
exit; 
  RPI_HW_Start([InstSignalHandler]);
  SetLength(range,maxcnt);
  FillWaveTable;
  GPIO_SetStruct(GPIO_struct,1,gpio,'WAVE-TEST',[FRQHW]);
  if GPIO_Setup (GPIO_struct) then 
  begin
    if FRQ_Setup(GPIO_struct,freqHz) then
	begin
	  FRQ_Switch(GPIO_struct,true);	// switch freq ON 
      repeat
        for n:= 0 to (maxcnt-1) do 
	    begin
//	      mmap_arr^[GPIO_struct.FRQ_DIVIdx]:=(BCM_PWD or ((range[n] and $fff) shl 12));	
writeln('#',n,' val:',range[n]);		
	    end;
      until terminateProg;
      FRQ_Switch(GPIO_struct,false);	// switch freq OFF
      GPIO_set_INPUT(gpio);
	end;
  end;
  SetLength(range,0);
end;

procedure FRQ_Test; 
const freqHz=1000000; gpio=4; // (1MHz on GPIO#4)
var  GPIO_struct:GPIO_struct_t; _mode,b:byte; FRQ_CTLIdx,FRQ_DIVIdx:longword; 
     reg,regctl,regdiv:longword; initok:boolean;		
begin 
  writeln('FRQ_Test: you should see a freq. ',freqHz:0,'Hz on GPIO',gpio:0,' minf:',(CLK_GetMinFreq/1000):0:1,'kHz maxf:',(CLK_GetMaxFreq/1000):0:1,' kHz');  
  if CLK_ValidFreq(freqHz) then
  begin
    GPIO_SetStruct(GPIO_struct,1,gpio,'FRQ HW TEST',[FRQHW]);
    if GPIO_Setup (GPIO_struct) then 
    begin
	  for b:= 0 to 3 do
      begin
        CLK_GetRegIdx(b,regctl,regdiv);
        reg:=BCM_GETREG(regdiv);  
	    writeln(Hex(BCM_REGAdr(regdiv),8),':  ',Hex(reg,8),' divisor:',CLK_GetDivisor(reg):0:5);
      end;
	  initok:=FRQ_GetClkRegIdx(gpio,_mode); 	
      if initok then initok:=CLK_GetRegIdx(_mode,FRQ_CTLIdx,FRQ_DIVIdx); 
	  if initok then
	  begin
	    for b:=0 to 3 do
	    begin
		  writeln('Mash: ',b:0,' ',Hex(CLK_GetMashValue(b),4)); 
		end;
	    show_regs('GMGP'+Num2Str(_mode,0)+'CTL',CLK_BASE_OFS,FRQ_CTLIdx,FRQ_DIVIdx,0,false); 
        initok:=FRQ_Setup(GPIO_struct,freqHz);
	    show_regs('GMGP'+Num2Str(_mode,0)+'CTL',CLK_BASE_OFS,FRQ_CTLIdx,FRQ_DIVIdx,0,false); 
//	    Clock_show_regs;
	    delay_msec(60000);
	    FRQ_Switch(GPIO_struct,false);
	  end;
    end;	
  end;
end;

procedure CLK_Test;
const gpioPWM=13; // (PWM1/GPIO#13/Pin33)
	  gpioFRQ=20; // (OSC/GPIO#20/Pin38) 
var mode_pll,MASH,n:byte; reg,regctl,regdiv,DIVIF:longword; 
    fr,FREQ_O_min,FREQ_O_avg,FREQ_O_max:real; ok:boolean;
begin
  mode_pll:=1; fr:=18.32*1000000;
  ok:=CLK_GetClkFreq(3,CLK_GetFreq(mode_pll),fr,FREQ_O_min,FREQ_O_avg,FREQ_O_max,MASH,DIVIF);
  writeln('CLK_Tst, mode:',mode_pll:0,' f:',fr:0:2,' fmin:',FREQ_O_min:0:2,' favg:',FREQ_O_avg:0:2,' fmax:',FREQ_O_max:0:2,' MASH:',MASH,' DIVIF:0x',Hex(DIVIF,8),' ok:',ok);
  for n:= 0 to 3 do
  begin
    CLK_GetRegIdx(n,regctl,regdiv);
    reg:=BCM_GETREG(regdiv);  
	writeln(Hex(BCM_REGAdr(regdiv),8),':  ',Hex(reg,8),' divisor:',CLK_GetDivisor(reg):0:5);
  end;
end;

procedure GPIO_set_PINMODE(gpio:longword; portfkt:t_port_flags);
// http://wiki.freepascal.org/Lazarus_on_Raspberry_Pi#5._PiGPIO_Low-level_native_pascal_unit_.28GPIO_control_instead_of_wiringPi_c_library.29
var akft:t_port_flags;
begin
//LOG_Writeln(LOG_DEBUG,'GPIO_set_PINMODE: GPIO'+Num2Str(gpio,0)+' Mode: '+Num2Str(ord(portfkt),0)); 
  case portfkt of
    INPUT : GPIO_set_INPUT (gpio);
    OUTPUT: GPIO_set_OUTPUT(gpio);
	ALT0,ALT1,ALT2,ALT3,ALT4,
    ALT5  : GPIO_set_ALT   (gpio,portfkt); 	
    I2C:	begin
			  akft:=INPUT; 
			  case gpio of
					 0,1,2,3,28,29:	akft:=ALT0;
			  end; // case
			  if (akft<>INPUT)	then GPIO_set_ALT(gpio,akft)
								else GPIO_MSG_INFO(LOG_ERROR,'GPIO_set_PINMODE: ',gpio,portfkt);   		
    		end;
	PWMHW : begin
			  akft:=INPUT; 
			  case gpio of
					 12,13,40,41,45:akft:=ALT0;
					 18,19: 		akft:=ALT5;
					 52,53:			akft:=ALT1;
			  end; // case
			  if (akft<>INPUT)	then GPIO_set_ALT(gpio,akft)
								else GPIO_MSG_INFO(LOG_ERROR,'GPIO_set_PINMODE: ',gpio,portfkt); 		
		    end;
    else GPIO_MSG_INFO(LOG_ERROR,'GPIO_set_PINMODE: ',gpio,portfkt); 
  end; // case
end;

procedure GPIO_Switch(var GPIO_struct:GPIO_struct_t); // Read GPIOx Status in Struct
var sh:string;
begin
  with GPIO_struct do
  begin
    if initok then
    begin	
	  if not (simulation IN portflags) then 
	  begin 
		ein:=(GPIO_get_PIN(gpio) xor (mask_pol<>0));
	  end;
	  sh:=description;
	  if sh='' then sh:='GPIO_Switch(Num#'+Num2Str(nr,0)+'/GPIO#'+Num2Str(gpio,0)+
					'/HWPin#'+Num2Str(HWPin,0)+')';
//	  writeln(sh+	' ReversePolarity: '+Bool2Str((mask_pol<>0))+' SignalLevel: '+Bool2Str(ein));	  
    end
    else LOG_Writeln(LOG_ERROR,'GPIO_Switch HDRPin:'+Num2Str(HWPin,0)+' not registered');
  end;
end;

procedure GPIO_Switch(var GPIO_struct:GPIO_struct_t; switchon:boolean); // switch GPIOx on/off
var sh:string; 
begin
  with GPIO_struct do
  begin
    if initok then
    begin 
      if switchon<>ein then 
	  begin
	    sh:=description;
		if sh='' then sh:='GPIO_Switch(Num#'+Num2Str(nr,0)+'/GPIO#'+Num2Str(gpio,0)+
					'/HWPin#'+Num2Str(HWPin,0)+')';
//		writeln(sh+	' ReversePolarity: '+Bool2Str((mask_pol<>0))+' SignalLevel: '+Bool2Str(switchon));
				   
		if not (simulation IN portflags) then 
		begin // only on level change
		  if switchon then mmap_arr^[regset]:=mask_1Bit else mmap_arr^[regclr]:=mask_1Bit;
		end;
	  end;
	  ein:=switchon;
    end else LOG_Writeln(LOG_ERROR,'GPIO_Switch HDRPin:'+Num2Str(HWPin,0)+' not registered');
  end;
end;

procedure GPIO_SetStruct(var GPIO_struct:GPIO_struct_t; num,gpionum:longint; desc:string; flags:s_port_flags);
//e.g. GPIO_SetStruct(structure,3,8,'description',[INPUT,PullUP,ReversePOLARITY]);
begin  
  with GPIO_struct do
  begin	
	gpio:=gpionum; HWPin:=GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio); 
	nr:=num; description:=desc; portflags:=flags; FRQ_freq_Hz:=0.0;
	RPI_HDR_SetDesc(HWPin,desc);
	idxofs_1Bit:=0; idxofs_3Bit:=0; mask_1Bit:=0; mask_3Bit:=0; mask_pol:=0; 
	regget:=GPIOONLYREAD; regset:=GPIOONLYREAD; regclr:=GPIOONLYREAD; ein:=false;
	with ThreadCtrl do begin TermThread:=true; ThreadRunning:=false; end; 
//	plausibility check and clean-up of port flags 
	if (PWMHW 		IN portflags)  or 
	   (PWMSW 		IN portflags)  then portflags:=portflags+[OUTPUT];
    if (INPUT  	    IN portflags)  and 
	   (OUTPUT      IN portflags)  then portflags:=portflags-[OUTPUT,PWMHW,PWMSW]; // cannot be both		  
	if (PullUP      IN portflags)  and 
	   (PullDOWN    IN portflags)  then portflags:=portflags-[PullDOWN]; // cannot be both		  		  
	if (RisingEDGE  IN portflags)  and 
	   (not(INPUT   IN portflags)) then portflags:=portflags-[RisingEDGE]; 
    if (FallingEDGE IN portflags)  and 
	   (not(INPUT   IN portflags)) then portflags:=portflags-[FallingEDGE]; 
	if (PWMHW IN portflags) and (not GPIO_FCTOK(gpio,[PWMHW])) then
	begin
	  LOG_writeln(LOG_ERROR,'GPIO_SetStruct: GPIO'+Num2Str(gpio,0)+' can not be PWMHW');
	  portflags:=portflags-[PWMHW]+[PWMSW];		
	end;
	if (FRQHW IN portflags) then
    begin
	  portflags:=portflags-[OUTPUT,ALT0,ALT5];
	  if GPIO_FCTOK(gpio,[FRQHW]) then
	  begin
	    portflags:=portflags+[ALT0];	
        if (gpio=GPIO_FRQ20_CLK0) or (gpio=GPIO_FRQ21_CLK1) 
		  then portflags:=portflags-[ALT0]+[ALT5];	  
	  end
	  else
	  begin
	    LOG_writeln(LOG_ERROR,'GPIO_SetStruct: GPIO'+Num2Str(gpio,0)+' can not be FRQHW');
	    portflags:=portflags-[FRQHW];		
	  end;
	end;
	if (portflags=[]) 			   then portflags:=[INPUT]; 
	initok:=((gpio>=0) and (gpio<64)); 
	if initok then 
	begin
	  GPIO_get_mask_and_idxOfs(GPFSEL,gpio,idxofs_3Bit,mask_3Bit);
	  GPIO_get_mask_and_idxOfs(GPSET, gpio,idxofs_1Bit,mask_1Bit);
	  regget:=GPLEV+idxofs_1Bit; 
	  if (ReversePOLARITY IN portflags) then 
	  begin 
	    regset:=GPCLR+idxofs_1Bit; 
		regclr:=GPSET+idxofs_1Bit; 
		mask_pol:=mask_1Bit;
	  end
	  else 
	  begin 
	    regset:=GPSET+idxofs_1Bit; 
		regclr:=GPCLR+idxofs_1Bit; 
		mask_pol:=0;
	  end;
	end;
    pwm_SetStruct(GPIO_struct); // set default values for pwm
//  GPIO_ShowStruct(GPIO_struct);
  end;
end;

procedure GPIO_SetStruct(var GPIO_struct:GPIO_struct_t);
begin
  GPIO_SetStruct(GPIO_struct,0,-1,'',[INPUT]);
end;

function  GPIO_Setup(var GPIO_struct:GPIO_struct_t):boolean;
var driveStrength:byte; // drivStrngth:boolean;
begin
  with GPIO_struct do
  begin
    if initok then 
	begin
	  if gpio<0 then
	  begin
	    gpio:=-1; initok:=false;
	    LOG_Writeln(LOG_ERROR,'GPIO_Reg for HDRPin: '+Num2Str(HWPin,0)+' can not be mapped to GPIO num');
	  end
	  else
	  begin
	    if not (simulation IN portflags)then
	    begin	
//		  setup of portflags
		  ein:=false;
		  if (FallingEDGE  	IN portflags) then GPIO_set_edge_falling(gpio,true); 
		  if (RisingEDGE   	IN portflags) then GPIO_set_edge_rising (gpio,true); 
//		  writeln('GPIO_Setup: ',ord(port_dir));
          if (INPUT  		IN portflags) then 
          begin 
        	GPIO_set_PINMODE (gpio,INPUT);  
          end; 
	      if (OUTPUT 		IN portflags) then 
		  begin 
		    GPIO_set_PINMODE (gpio,OUTPUT);  
			GPIO_Switch(GPIO_struct,	(InitialHIGH 	 IN portflags) or
										(ReversePolarity IN portflags)
						); 
		  end;
		  										driveStrength:=$b;
		  if (DS2mA		  	IN portflags) then 	driveStrength:= 0;
		  if (DS4mA		  	IN portflags) then 	driveStrength:= 1;
		  if (DS6mA		  	IN portflags) then 	driveStrength:= 2;
		  if (DS8mA		  	IN portflags) then 	driveStrength:= 3;
		  if (DS10mA	  	IN portflags) then 	driveStrength:= 4;
		  if (DS12mA	  	IN portflags) then 	driveStrength:= 5;
		  if (DS14mA	  	IN portflags) then 	driveStrength:= 6;
		  if (DS16mA	  	IN portflags) then 	driveStrength:= 7;
		  if (driveStrength>7) then
		  	GPIO_set_PAD(	 gpio,
		  					(noPADslew IN portflags),
		  					(noPADhyst IN portflags),
							 drivestrength);
		  
		  if (PullDOWN 		IN portflags) then GPIO_set_PULLDOWN    (gpio,true); 
		  if (PullUP   		IN portflags) then GPIO_set_PULLUP      (gpio,true); 
(*		  if (PullEnable	IN portflags) then 
		  begin
		    if (ReversePolarity	IN portflags) then GPIO_set_PULLDOWN(gpio,true)
		    								  else GPIO_set_PULLUP	(gpio,true); 	
		  end; *)
		  if (PWMSW			IN portflags) or (PWMHW IN portflags) 
		    then initok:=pwm_Setup(GPIO_struct);
        end;		
	  end;
	end else Log_Writeln(LOG_ERROR,'GPIO_Setup: GPIO_struct is not initialized'); 
  end; // with
  GPIO_Setup:=GPIO_struct.initok;
end;

procedure xyx(reg1,reg2,mask:longword); begin mmap_arr^[reg1]:=mask; mmap_arr^[reg2]:=mask; end;
  
procedure Toggle_Pin_very_fast(gpio:longword; cnt:qword);
// just to show how fast (without overhead) we can toggle PINxx. 
// with rpi2 B+ @ 900MHz
// Result(fastway=true): >20Mhz // Result(fastway=false): 2.4Mhz 
const fastway=true;
var i:qword; GPIO_struct:GPIO_struct_t; s,e:TDateTime; 
begin
  i:=0;
  GPIO_SetStruct(GPIO_struct,1,gpio,'GPIO Toggle TEST',[OUTPUT]);
  if GPIO_Setup (GPIO_struct) then
  begin
    with GPIO_struct do
	begin
//GPIO_show_regs;	
	  GPIO_ShowStruct(GPIO_struct);
	  writeln('Start with ',cnt:0,' samples, GPIO',gpio:0,' Pin:',HWPin:0,' Mask:0x',Hex(mask_1Bit,8),' idxofs_1Bit:0x',Hex(idxofs_1Bit,2),')');
      s:=now; // start measuring time 
	  repeat 
	    {$warnings off} 
	      if fastway then
		  begin // >20MHz
//          xyx(regset,regclr,mask_1Bit); // 15MHz, takes 30% times longer ??!!
	        mmap_arr^[regset]:=mask_1Bit; (* High*) mmap_arr^[regclr]:=mask_1Bit; (* Low *)
		  end
		  else 
		  begin // 2-3Mhz only ???!!!
		    GPIO_Switch(GPIO_struct,true); GPIO_Switch(GPIO_struct,false);
		  end;
		{$warnings on} 
		inc(i); 
	  until (i>=cnt);
      e:=now; // end measuring time
	  writeln('End: ',FormatDateTime('yyyy-mm-dd hh:nn:ss',e),' (',(cnt/MilliSecondsBetween(e,s)/1000):0:3,'MHz)');
	end; 
  end else writeln('Can not initialize GPIO',gpio);
end;

procedure Toggle_STATUSLED_very_fast; begin Toggle_Pin_very_fast(RPI_status_led_GPIO,100000000); end;	

procedure LED_Status(ein:boolean); begin GPIO_set_PIN(RPI_status_led_GPIO,ein); end;

procedure GPIO_PIN_TOGGLE_TEST;
{ just for demo reasons }
const looptimes=10; waittime_ms	= 1000; // 0.5Hz; let Status LED blink  
var   lw:longword;
begin
//GPIO_show_regs;
  writeln('Start of GPIO_PIN_TOGGLE_TEST (Let the Status-LED blink ',looptimes:0,' times)');
  writeln('Set GPIO',RPI_status_led_GPIO:0,' to OUTPUT'); 
  GPIO_set_OUTPUT(RPI_status_led_GPIO);   
  for lw := 1 to looptimes do
  begin
    writeln(looptimes-lw+1:3,'. Set StatusLED (GPIO',RPI_status_led_GPIO,') to 1'); LED_Status(true);  sleep(waittime_ms);
	writeln(looptimes-lw+1:3,'. Set StatusLED (GPIO',RPI_status_led_GPIO,') to 0'); LED_Status(false); sleep(waittime_ms);
	writeln;
  end;
  writeln('End of GPIO_PIN_TOGGLE_TEST');
end;
  
procedure GPIO_set_BIT(regidx,gpio:longword;setbit,readmodifywrite:boolean); { set or reset pin in gpio register part }
var idx,mask:longword;
begin
  GPIO_get_mask_and_idx(regidx,gpio,idx,mask);
//Writeln('GPIO_set_BIT: GPIO'+Num2Str(gpio,0)+' level: '+Bool2Str(setbit)+' Reg: 0x'+Hex(regidx,8)+' idx: 0x'+Hex(idx,8)+' mask: 0x'+Hex(mask,8));   
  if setbit then BCM_SETREG(idx,    mask ,false,readmodifywrite)
            else BCM_SETREG(idx,not(mask),true, readmodifywrite);
end;
  
procedure GPIO_set_PIN(gpio:longword;highlevel:boolean);
{ Set RPi GPIO to high or low level: Speed @ 700MHz ->  1.25MHz }
begin
//Log_Writeln(LOG_DEBUG,'GPIO_set_PIN: '+Num2Str(gpio,0)+' level '+Bool2Str(highlevel));
//Writeln('GPIO_set_PIN: '+Num2Str(gpio,0)+' level '+Bool2Str(highlevel));
  if highlevel then GPIO_set_BIT(GPSET,gpio,true,false) else GPIO_set_BIT(GPCLR,gpio,true,false);
  { sleep(1); }
end;

function  GPIO_get_PIN   (gpio:longword):boolean;
// Get RPi GPIO pin Level is true when Pin level is '1'; false when '0'; Speed @ 700MHz ->  2.33MHz 
var idx,mask:longword;
begin
  GPIO_get_mask_and_idx(GPLEV,gpio,idx,mask);
  GPIO_get_PIN:=((BCM_GETREG(idx) and mask)>0);
end;

procedure GPIO_Pulse(gpio,pulse_ms:longword);
begin
  GPIO_set_pin(gpio,true);
  delay_msec(pulse_ms);
  GPIO_set_pin(gpio,false);
end;

procedure GPIO_set_GPPUD(enable,pullup:boolean); 
begin 
  if enable then
  begin
    if pullup then BCM_SETREG(GPPUD,$02,false,false) else BCM_SETREG(GPPUD,$01,false,false);
  end
  else BCM_SETREG(GPPUD,$00,false,false);
  delay_msec(1);
end; { set GPIO Pull-up/down Register (GPPUD) } 

procedure GPIO_set_PAD(gpio:longword; noSLEW,noHYST:boolean; drivestrength:byte);
// https://de.scribd.com/doc/101830961/GPIO-Pads-Control2
var mask:longword;
begin
  mask:=BCM_PWD or (drivestrength and	$00000007);
  if (not noHYST) then mask:=mask or 	$00000008;
  if (not noSLEW) then mask:=mask or 	$00000010;
  LOG_Writeln(LOG_DEBUG,'GPIO_set_PADcurrent: GPIO'+Num2Str(gpio,0)+' '+Num2Str(drivestrength,0)); 
  case gpio of
	00..27:	BCM_SETREG(PADS_GPIO00_27,mask,false,false);	// 0x7e10 002c PADS (GPIO  0-27)
	28..45:	BCM_SETREG(PADS_GPIO28_45,mask,false,false);	// 0x7e10 0030 PADS (GPIO 28-45)
	46..53:	BCM_SETREG(PADS_GPIO46_53,mask,false,false);	// 0x7e10 0034 PADS (GPIO 46-53)
  end; // case
end;

procedure GPIO_set_PULLUPORDOWN(gpio:longword; enable,pullup:boolean); // pulldown: pullup=false;
// approximately 50KΩ
var idx,mask:longword;
begin 
  LOG_Writeln(LOG_DEBUG,'GPIO_set_PULLUPORDOWN: GPIO'+Num2Str(gpio,0)+' '+Bool2Str(enable)+' '+Bool2Str(pullup)); 
  GPIO_get_mask_and_idx(GPPUDCLK,gpio,idx,mask);
  GPIO_set_GPPUD(enable,pullup); 				// assert clock to GPPUDCLKn
  BCM_SETREG(idx,mask,false,false);
  delay_msec(1);
  GPIO_set_GPPUD(false, pullup); 				// deassert clock from GPPUDCLKn
  BCM_SETREG(idx,0,false,false);  
  delay_msec(1);
end;
procedure GPIO_set_PULLUP  (gpio:longword; enable:boolean); begin GPIO_set_PULLUPORDOWN(gpio,enable,true);  end;	// enable or disable PULLUP
procedure GPIO_set_PULLDOWN(gpio:longword; enable:boolean); begin GPIO_set_PULLUPORDOWN(gpio,enable,false); end;	// enable or disable PULLDOWN

procedure GPIO_set_edge_rising(gpio:longword; enable:boolean);  { Pin RisingEdge  Detection Register (GPREN) }
begin 
  Log_Writeln(LOG_DEBUG,'GPIO_set_edge_rising: GPIO'+Num2Str(gpio,0)+' enable: '+Bool2Str(enable)); 
  GPIO_set_BIT(GPREN,gpio,enable,true);   { Pin RisingEdge  Detection }
end;

procedure GPIO_set_edge_falling(gpio:longword; enable:boolean); { Pin FallingEdge  Detection Register (GPFEN) }
begin 
  Log_Writeln(LOG_DEBUG,'GPIO_set_edge_falling: GPIO'+Num2Str(gpio,0)+' enable: '+Bool2Str(enable)); 
  GPIO_set_BIT(GPFEN,gpio,enable,true);  { Pin FallingEdge Detection }
end;

procedure GPIO_PWM_Test(gpio:longint; HWPWM:boolean; freq_Hz:real; dutyrange,startval:longword);
// only for PWM0:Pin12:GPIO18 PWM1:Pin35:GPIO19
const maxcnt=2; 
var i,cnt:longint; GPIO_struct:GPIO_struct_t;
begin
  if HWPWM then  GPIO_SetStruct(GPIO_struct,1,gpio,'HW PWM_TEST',[PWMHW])
			else GPIO_SetStruct(GPIO_struct,1,gpio,'SW PWM_TEST',[PWMSW]);
  pwm_SetStruct (GPIO_struct,PWM_MS_MODE,freq_Hz,dutyrange,startval); // ca. 50Hz (50000/1000) -> divisor: 384	
  pwm_SetClock  (GPIO_struct);
  if GPIO_Setup (GPIO_struct) then
  begin
    GPIO_ShowConnector; GPIO_ShowStruct(GPIO_struct); 		
	i:=0; cnt:=1;
	repeat
	  if (i>(dutyrange-1)) then 
	  begin 
	    pwm_Write(GPIO_struct,dutyrange-1);	
		writeln('Loop(',cnt,'/',dutyrange,'): reached max. pwm value: ',dutyrange-1); sleep(30); 
		GPIO_ShowStruct(GPIO_struct); 
		i:=0; inc(cnt);
	  end else pwm_Write(GPIO_struct,i);
//    if (i=(dutyrange div 2)) then readln;  // for measuring with osci
	  if HWPWM then begin inc(i); sleep(10); end else begin inc(i,10); sleep(10); end;	// ms
	until (cnt>maxcnt);
	pwm_Write     (GPIO_struct,0);	// set last value to 0
	pwm_SetStruct (GPIO_struct); 	// reset to PWM default values
    sleep(100); // let SW Thread time to terminate
  end else Log_Writeln(LOG_ERROR,'GPIO_PWM_Test: GPIO'+Num2Str(GPIO_struct.gpio,0)+' Init has failed'); 	
end;

procedure GPIO_PWM_Test; // Test with GPIO18 PWM0 on Connector Pin12
const gpio=GPIO_PWM0; 
var dc,f_hz:longword;
begin
  f_hz:=50; dc:=PWM_GetMaxDtyC(f_hz);	// get the best DutyCycle for this freq.
  writeln('GPIO_PWM_Test with GPIO',gpio,' Connector Pin',GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio),' SOFTWARE based');
  GPIO_PWM_Test(gpio,false,f_hz,dc,0); // SW PWM Test

  f_hz:=5000; dc:=PWM_GetMaxDtyC(f_hz);	// get the best DutyCycle for this freq.
  writeln('GPIO_PWM_Test with GPIO',gpio,' Connector Pin',GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio),' HARDWARE based');
  GPIO_PWM_Test(gpio,true, f_hz,dc,0);  // HW PWM Test
  writeln('GPIO_PWM_Test END');
end;

procedure GPIO_Test(HWPinNr:longword; flags:s_port_flags);
const loopmax=2;
var i:longint; GPIO_struct:GPIO_struct_t;
begin
  GPIO_SetStruct(GPIO_struct,1,GPIO_MAP_HDR_PIN_2_GPIO_NUM(HWPinNr),'GPIO_Test',flags);
  if GPIO_Setup (GPIO_struct) then
  begin
    with GPIO_struct do
	begin
	  description:='GPIO_Test(HWPin#'+Num2Str(HWPin,0)+'/GPIO#'+Num2Str(gpio,0)+')';
	  if (OUTPUT IN flags) then
	  begin
        writeln('Test OUTPUT HWPin: '+Num2Str(HWPin,0)+'  GPIO: '+Num2Str(gpio,0)); 
	    for i := 1 to loopmax do
	    begin
	      writeln('  for setting Pin to HIGH, pls. push <CR> button'); readln;
          GPIO_Switch(GPIO_struct,true); 
          writeln('  for setting Pin to LOW,  pls. push <CR> button'); readln;
	      GPIO_Switch(GPIO_struct,false); 
	    end;
	    writeln('Test next PIN, pls. push <CR> button'); readln;
      end; // Output-Test
	  if (INPUT IN flags) then
	  begin
        writeln('Test INPUT HWPin: '+Num2Str(HWPin,0)+'  GPIO: '+Num2Str(gpio,0)); 
		for i := 1 to loopmax do
	    begin
	      writeln('  for reading Pin, pls. push <CR> button'); readln; 
		  GPIO_Switch(GPIO_struct); // Read GPIO
		  writeln(description+': '+Bool2LVL(ein));
		end;
	  end; // Input-Test
	end; // with
  end else Writeln('GPIO_Test: can not Map HWPin:'+Num2Str(HWPinNr,0)+' to valid GPIO num');	
  writeln;
end;

procedure GPIO_TestAll;
// for testing of correct operation. (only OUTPUT tests)
begin
  begin // 26 Pin Hdr
    GPIO_Test(07,[OUTPUT]); GPIO_Test(11,[OUTPUT]); GPIO_Test(12,[OUTPUT]); 
	GPIO_Test(13,[OUTPUT]); GPIO_Test(15,[OUTPUT]); GPIO_Test(16,[OUTPUT]); 
	GPIO_Test(18,[OUTPUT]); GPIO_Test(22,[OUTPUT]); 
  end;
  if RPI_hdrpincount>=40 then
  begin // 40 PIN Hdr
    GPIO_Test(29,[OUTPUT]); GPIO_Test(31,[OUTPUT]); GPIO_Test(32,[OUTPUT]); 
	GPIO_Test(33,[OUTPUT]); GPIO_Test(35,[OUTPUT]); GPIO_Test(36,[OUTPUT]); 
	GPIO_Test(37,[OUTPUT]); GPIO_Test(38,[OUTPUT]); GPIO_Test(40,[OUTPUT]);
  end;
end;

procedure SERVO_End(var SERVO_struct:SERVO_struct_t);
begin PWM_End(SERVO_struct.HWAccess); end;

procedure SERVO_End(hndl:longint);
var n:longint;
begin
  if hndl<0 then
  begin
    for n:= 1 to Length(SERVO_struct) do SERVO_End(SERVO_struct[n-1]);
    SetLength(SERVO_struct,0);
  end else SERVO_End(SERVO_struct[hndl]);
end;

procedure SERVO_SetStruct(var SERVO_struct:SERVO_struct_t; dty_min,dty_mid,dty_max:longword; ang_min,ang_mid,ang_max,speed:longint);
begin
  with SERVO_struct do
  begin
    if ((ang_min<=ang_mid) and (ang_mid<=ang_max)) and 
	   ((dty_min<=dty_mid) and (dty_mid<=dty_max)) then
    begin
	  min_dutycycle:=dty_min; mid_dutycycle:=dty_mid; max_dutycycle:=dty_max; 
	  min_angle:=	 ang_min; mid_angle:=    ang_mid; max_angle:=    ang_max;
	end
	else
	begin
	  min_dutycycle:=SRVOMINDC;  mid_dutycycle:=SRVOMIDDC;  max_dutycycle:=SRVOMAXDC;  // SG90 ms in Ticks
	  min_angle:=	 SRVOMINANG; mid_angle:=    SRVOMIDANG; max_angle:=    SRVOMAXANG; // SG90 degree Values 
	  LOG_writeln(LOG_ERROR,'SERVO_SetStruct: invalid duty cycle or angle values. set it to default values');
	end;
	speed60deg:=speed;
	angle_current:=max_angle+1;			// just to force 1. servo-movement to 0Deg
  end;
end;

procedure SERVO_Write(var SERVO_struct:SERVO_struct_t; angle:longint; syncwait:boolean);
var setval,angle_old:longint;
begin
  with SERVO_struct do
  begin
    if (angle_current<>angle) then
	begin
	  angle_old:=angle_current; angle_current:=angle; 
	  if angle_current<min_angle then angle_current:=min_angle; 
	  if angle_current>max_angle then angle_current:=max_angle;
	  setval:=mid_dutycycle;
	  if ((min_angle<>0) and (max_angle<>0) and (angle_current<>mid_angle)) then
      begin	
	    if (angle_current>=min_angle) and (angle_current<mid_angle) then
	    begin
		  setval:=round(((min_angle-angle_current)/min_angle) * 
		                 (mid_dutycycle-min_dutycycle) + min_dutycycle);
//        writeln('Angle-: ',angle_current);
	    end
	    else
	    begin
//        writeln('Angle+: ',angle_current);
		  setval:=round((angle_current/max_angle) * 
		                (max_dutycycle-mid_dutycycle) + mid_dutycycle);
	    end;
	  end;
//    writeln('setval1: ',setval);
//    transform setval to dutyrange e.g. 0..1000
      with SERVO_struct.HWAccess.PWM do
	  begin
	    if (pwm_dutyrange<>0) and (pwm_period_us<>0) 
	      then setval:=abs(round(setval/(pwm_period_us/pwm_dutyrange)))
	      else setval:=0;	 
      end; // with		
//    writeln('setval2: ',setval,' #######################################');
	  pwm_Write(SERVO_struct.HWAccess,setval);
//    writeln('SyncWaitTime(ms):',round((abs(angle_old-angle_current)/60)*speed60Deg));
	  if syncwait then 
	    delay_msec(round((abs(angle_old-angle_current)/60)*speed60Deg));
    end;	
  end; // with
end;

procedure SERVO_Setup(var SERVO_struct:SERVO_struct_t; 
						HWPinNr,nr,maxval,
						dcmin,dcmid,dcmax:longword; 
						angmin,angmid,angmax,speed:longint;
						desc:string; freq:real; flags:s_port_flags);
var flgs:s_port_flags; _gpio:longint;
begin
  _gpio:=GPIO_MAP_HDR_PIN_2_GPIO_NUM(HWPinNr); 
  if (PWMSW IN flags) or (PWMHW IN flags) then flgs:=flags else flgs:=flags+[PWMSW];
  if (PWMHW IN flags) and (not GPIO_HWPWM_capable(_gpio)) then flgs:=flags+[PWMSW]-[PWMHW];
  with SERVO_struct do
  begin
    SERVO_SetStruct(SERVO_struct,dcmin,dcmid,dcmax,angmin,angmid,angmax,speed);
    GPIO_SetStruct (SERVO_struct.HWAccess,nr,_gpio,desc,flgs);
    pwm_SetStruct  (SERVO_struct.HWAccess,PWM_MS_MODE,freq,maxval,dcmid);
    pwm_SetClock   (SERVO_struct.HWAccess);
  end; // with
end;

procedure SERVO_GetData(var nr,yaw,pitch,roll:longint);
// Get Data from Accelerator-/Gyro-/Compass-Sensors (e.g. Quaternion, Euler-Angels)
// use Data and convert it to new Servo positions
// this is just for demo reasons
var min,mid,max:longint;
begin
  min:=SRVOMINANG; mid:=SRVOMIDANG; max:=SRVOMAXANG;
  case (nr mod 12) of // just a quick demo
      1: begin yaw:=max; pitch:=mid; roll:=mid; end; 
	  2: begin yaw:=max; pitch:=max; roll:=mid; end; 
	  3: begin yaw:=max; pitch:=max; roll:=max; end; 
	  4: begin yaw:=mid; pitch:=max; roll:=max; end; 
	  5: begin yaw:=mid; pitch:=mid; roll:=max; end; 
	  7: begin yaw:=min; pitch:=mid; roll:=mid; end; 
	  8: begin yaw:=min; pitch:=min; roll:=mid; end; 
	  9: begin yaw:=min; pitch:=min; roll:=min; end; 
	 10: begin yaw:=mid; pitch:=min; roll:=min; end; 
	 11: begin yaw:=mid; pitch:=mid; roll:=min; end; 
    else begin yaw:=mid; pitch:=mid; roll:=mid; end;
  end;
  inc(nr); 
end;

procedure SERVO_Test;
// tested with TowerPro Micro Servos 9g SG90 Datasheet values 
//   "0" (1.5 ms pulse) is middle, 
//  "90" ( ~2 ms pulse) is all the way to the right, 
// "-90" ( ~1 ms pulse) is all the way to the left.
// Frequency: 50Hz-> 20ms period (20000us)
const   
  freq=SERVO_FRQ; speed=SERVO_Speed;
  HWPinNr_YAW=  12; // GPIO18 HW-PWM
  YAW_minAng=SRVOMINANG;	YAW_midANG=SRVOMIDANG;	    YAW_maxAng=SRVOMAXANG;// SG90 degree Values
  YAW_min=   SRVOMINDC;     YAW_mid=   SRVOMIDDC; 	  	YAW_max=   SRVOMAXDC; // SG90 ms in Ticks
  HWPinNr_PITCH=16; // GPIO23 SW-PWM	
  PITCH_min=   YAW_min; 	PITCH_mid=   YAW_mid; 		PITCH_max=   YAW_max;
  PITCH_minAng=YAW_minAng;	PITCH_midAng=YAW_midAng;	PITCH_maxAng=YAW_maxANG;
  HWPinNr_ROLL= 18; // GPIO24 SW-PWM
  ROLL_min=   YAW_min; 		ROLL_mid=   YAW_mid; 		ROLL_max=   YAW_max;
  ROLL_minAng=YAW_minAng;	ROLL_midAng=YAW_midAng;		ROLL_maxAng=YAW_maxANG;
var nr,yaw,pitch,roll,_dc:longint;
begin
  RPI_HW_Start([InstSignalHandler]);
  writeln('SERVO_Test: Start');
  SetLength(SERVO_struct,3);	// create data structures for 3 servos
  _dc:=PWM_GetMaxDtyC(freq);	// get the best DutyCycle for this freq.
  SERVO_Setup(  SERVO_struct[0],HWPinNr_YAW,  0,_dc,YAW_min,  YAW_mid,  YAW_max,  YAW_minAng,  YAW_midAng,  YAW_maxANG,  speed,'SERVO YAW  ',freq,[PWMHW]);
  SERVO_Setup(  SERVO_struct[1],HWPinNr_PITCH,1,_dc,PITCH_min,PITCH_mid,PITCH_max,PITCH_minAng,PITCH_midAng,PITCH_maxAng,speed,'SERVO PITCH',freq,[PWMSW]);
  SERVO_Setup(  SERVO_struct[2],HWPinNr_ROLL, 2,_dc,ROLL_min, ROLL_mid, ROLL_max, ROLL_minAng, ROLL_midAng, ROLL_maxAng, speed,'SERVO ROLL ',freq,[PWMSW]);
  if GPIO_Setup(SERVO_struct[0].HWAccess) and 
     GPIO_Setup(SERVO_struct[1].HWAccess) and
	 GPIO_Setup(SERVO_struct[2].HWAccess) then
  begin 
    nr:=0; 
    repeat // control loop
// Do SERVO_Write(SERVO_struct[<nr>],<new_servo_pos>,<syncwait>); 
	  SERVO_GetData(nr,yaw,pitch,roll);	// get new servo position data
	  writeln('Servos: ',yaw:4,' ',pitch:4,' ',roll:4);
	  SERVO_Write(SERVO_struct[0],yaw,  false); 
	  SERVO_Write(SERVO_struct[1],pitch,false); 
	  SERVO_Write(SERVO_struct[2],roll, false); 
      delay_msec(SERVO_Speed*round(90/60)); // let servo time for full turn
	until (nr>50) or terminateProg;
	for nr:=1 to Length(SERVO_struct) do SERVO_Write(SERVO_struct[nr-1],0,false);  
	delay_msec(SERVO_Speed*round(90/60)); // let servos time to turn to neutral position
	SERVO_End(-1);
	writeln('SERVO_Test: END');
  end else LOG_Writeln(LOG_ERROR,'SERVO_Test: could not be initialized');
end;

function  GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio:longint; mapidx:byte):longint; { Maps GPIO Number to the HDR_PIN, respecting rpi rev1 or rev2 board }
var hwpin,cnt:longint; 
begin
  hwpin:=-99; cnt:=1;
  if ((mapidx=1) or (mapidx<=gpiomax_map_idx_c)) then 
  begin
    while cnt<=max_pins_c do
	begin
	  if abs(GPIO_hdr_map_c[mapidx,cnt])=gpio then begin hwpin:=cnt; cnt:=max_pins_c; end;
	  inc(cnt);
	end;
  end;
//writeln('mapidx',mapidx:0,' HW-PIN: ',hwpin:2,' <- ',gpio:2);
  GPIO_MAP_GPIO_NUM_2_HDR_PIN:=hwpin;
end;  

function  GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio:longint):longint;
begin
  GPIO_MAP_GPIO_NUM_2_HDR_PIN:=GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio,RPI_gpiomapidx);
end;
  
function  GPIO_MAP_HDR_PIN_2_GPIO_NUM(hdr_pin_number:longint; mapidx:byte):longint; { Maps HDR_PIN to the GPIO Number, respecting rpi rev1 or rev2 board }
var GPIO_pin:longint;
begin
  if (hdr_pin_number>=1) and (hdr_pin_number<=max_pins_c) and 
     ((mapidx>=1) and (mapidx<=gpiomax_map_idx_c)) then GPIO_pin:=GPIO_hdr_map_c[mapidx,hdr_pin_number] else GPIO_pin:=WRONGPIN;
//writeln('mapidx',mapidx:0,' HW-PIN: ',hdr_pin_number:2,' -> ',GPIO_pin:2);
  GPIO_MAP_HDR_PIN_2_GPIO_NUM:=GPIO_pin;
end;

function  GPIO_MAP_HDR_PIN_2_GPIO_NUM(hdr_pin_number:longint):longint;
begin
  GPIO_MAP_HDR_PIN_2_GPIO_NUM:=GPIO_MAP_HDR_PIN_2_GPIO_NUM(hdr_pin_number,RPI_gpiomapidx);
end;

procedure GPIO_set_HDR_PIN(hw_pin_number:longword;highlevel:boolean); { Maps PIN to the GPIO Header, respecting rpi rev1 or rev2 board }
var pin:longint;
begin
  pin:=GPIO_MAP_HDR_PIN_2_GPIO_NUM(hw_pin_number,RPI_gpiomapidx);
  if pin>=0 then GPIO_set_PIN(longword(pin),highlevel);
end;

function  GPIO_get_HDR_PIN(hw_pin_number:longword):boolean; { Maps PIN to the GPIO Header, respecting rpi rev1 or rev2 board }
var pin:longint; lvl:boolean;
begin
  pin:=GPIO_MAP_HDR_PIN_2_GPIO_NUM(hw_pin_number,RPI_gpiomapidx);
  if pin>=0 then lvl:=GPIO_get_PIN(longword(pin)) else lvl:=false;
  GPIO_get_HDR_PIN:=lvl;
end;

function  ENC_GetVal(hdl:byte; ctrsel:integer):real; 
var val:real;
begin 
  val:=0;
  {$warnings off}
  if (hdl>=0) and (hdl<Length(ENC_struct)) then {$warnings on}
  begin
    with ENC_struct[hdl] do
    begin
      with CNTInfo do
      begin
	  	EnterCriticalSection(ENC_CS); 		
          case ctrsel of
        	0:	 val:=counter;
	    	1:	 val:=cycles;
	    	2:	 val:=switchcounter;
	    	3:	 if (countermax<>0) then val:=counter/countermax;
	    	4:	 val:=TurnRateStruct.fTurnRate_Hz;
	    	5:	 val:=switchlastpresstime;	// no reset last value
			6:	 begin val:=switchlastpresstime; switchlastpresstime:=0; end;
			7:	 val:=ord(kbdupcnt);
			8:	 val:=ord(kbddwncnt);
			9:	 val:=ord(kbdswitch);
	    	else val:=counter;
	      end; // case
	    end; // with
	  LeaveCriticalSection(ENC_CS);
    end; // with
  end else LOG_Writeln(LOG_ERROR,'ENC_GetVal: hdl '+Num2Str(hdl,0)+' out of range');
  ENC_GetVal:=val;  
end;

function  ENC_GetVal       (hdl:byte):real; begin ENC_GetVal:=       ENC_GetVal(hdl,0); end;
function  ENC_GetCycles    (hdl:byte):real; begin ENC_GetCycles:=    ENC_GetVal(hdl,1); end;
function  ENC_GetValPercent(hdl:byte):real; begin ENC_GetValPercent:=ENC_GetVal(hdl,3); end;
function  ENC_GetSwitch    (hdl:byte):real; begin ENC_GetSwitch:=    ENC_GetVal(hdl,2); end;
function  ENC_GetSwPtime   (hdl:byte):real; begin ENC_GetSwPtime:=   ENC_GetVal(hdl,5); end;

procedure ENC_IncSwCnt (var ENCInfo:ENC_CNT_struct_t; cnt:integer);
begin inc(ENCInfo.switchcounter,cnt); end;

procedure ENC_IncEncCnt(var ENCInfo:ENC_CNT_struct_t; cnt:integer);
begin inc(ENCInfo.counter,cnt); end;

function  ENC_GetCounter(var ENCInfo:ENC_CNT_struct_t):boolean;
begin
  with ENCInfo do
  begin
    switchlastpresstime:=round(ENC_GetSwPtime(Handle)); 
	switchcounterold:=	switchcounter; 	
	switchcounter:=		round(ENC_GetSwitch(Handle)); 
	counterold:=		counter; 		
	counter:=  			round(ENC_GetVal   (Handle));
	cyclesold:=			cycles;
	cycles:=			round(ENC_GetCycles(Handle));
	swsteps:=			switchcounter-switchcounterold;
	encsteps:=			counter-	  counterold;
	enccycles:=			cycles-	  	  cyclesold;
	case activitymodedetect of
	    1: ENC_activity:=	((encsteps <>0) or (swsteps<>0));
	    2: ENC_activity:=	((swsteps  <>0));
	    3: ENC_activity:=	((enccycles<>0));
	    4: ENC_activity:=	((encsteps <>0));
	  else ENC_activity:=	((enccycles<>0) or (swsteps<>0));
	end; // case
	if ENC_activity then
	begin
  	  if (enccycles>0) then kbdcode:=char(round(ENC_GetVal(Handle,7))); 
	  if (enccycles<0) then kbdcode:=char(round(ENC_GetVal(Handle,8))); 
  	  if (swsteps<>0)  then kbdcode:=char(round(ENC_GetVal(Handle,9)));
	end;
//	writeln('ENC_GetCounter: ',counter,' ',counterold,' ',encsteps,' Switch: ',switchcounter,' ',switchcounterold);
    ENC_GetCounter:=	ENC_activity;
  end; // with
end;
 
procedure ENC_End(hdl:integer); 
var i:integer; 
begin 
  if (hdl<0) then
  begin
    for i:= 1 to Length(ENC_struct) do Thread_End(ENC_struct[i-1].ThreadCtrl,100);
	SetLength(ENC_struct,0);
  end
  else
  begin
    if (hdl>=0) and (hdl<Length(ENC_struct)) then Thread_End(ENC_struct[hdl].ThreadCtrl,100);
  end;
end;

(*
  ENC_ptr = ^ENC_struct_t;
  ENC_CNT_ptr=^ENC_CNT_struct_t;
  ENC_CNT_struct_t = record	  
    Handle:integer;
    ENC_activity:boolean;
    switchcounter,switchcounterold,switchcountermax,switchlastpresstime,
    counter,counterold,countermax,cycles,cyclesold:longint;
    encsteps,enccycles,swsteps,Interval_ms:longint;
    enc,encold:real;
    fIntervalResetTime:TDateTime;
    activitymodedetect,
    steps_per_cycle:byte;
    kbdcode,kbdupcnt,kbddwncnt,kbdswitch:char;
    TurnRateStruct:FREQ_Determine_t;
  end; 
  ENC_struct_t = record					// Encoder data structure
    ENC_CS : TRTLCriticalSection;
	SyncTime: TDateTime;				// for syncing max. device queries
//  ENCptr:ENC_ptr; 
	ThreadCtrl:Thread_Ctrl_t;
	A_Sig,B_Sig,S_Sig:GPIO_struct_t;
	a,b,seq,seqold,deltaold,delta:longint;
	idxcounter,SwitchRepeatTime_ms,
	sleeptime_ms:longword;
	beepgpio:integer;
	ok,s2minmax:boolean;
	SwitchFiredSpecFunc:TProcedureNoArgCall;
	CNTInfo:ENC_CNT_struct_t;
	desc:string[RPI_hal_dscl];
  end;
*)
function  ENC_Device(ptr:pointer):ptrint;
(* seq	B	A	  AxorB		  delta	meaning	
	0	0	0		0			0	no change
	1	0	1		1			1	1 step clockwise
	2	1	1		0			2	2 steps clockwise or counter-clockwise (fault condition)
	3	1	0		1			3	1 step counter clockwise *)
var   hdl,cyclold:longint; regval:longword; dt,dt2:TDateTime; sw_change,swpress,sw1stpress:boolean;
begin 
  hdl:=longint(ptr); 
  if (hdl>=0) and (hdl<Length(ENC_struct)) then
  begin
    with ENC_struct[hdl] do
    begin
	  Thread_SetName(desc);  
	  ThreadCtrl.ThreadRunning:=true; ThreadCtrl.TermThread:=false;
//    writeln('ThreadStart ',TermThread,' ',sleeptime_ms); 
	  InitCriticalSection(ENC_CS);  
	  SyncTime:=now; dt:=SyncTime; dt2:=dt; sw1stpress:=true; sw_change:=false; 
      repeat
        cyclold:=CNTInfo.cycles;
		regval:=mmap_arr^[A_Sig.regget];
		if (((regval and A_Sig.mask_1Bit) xor A_Sig.mask_pol)>0) then a:=1 else a:=0;
		if (A_Sig.regget<>B_Sig.regget) then regval:=mmap_arr^[B_Sig.regget];
	    if (((regval and B_Sig.mask_1Bit) xor B_Sig.mask_pol)>0) then b:=1 else b:=0;
		seq:=(a xor b) or (b shl 1);
		if (S_Sig.gpio>=0) then 
		begin  // switch
		  if (B_Sig.regget<>S_Sig.regget) then regval:=(mmap_arr^[S_Sig.regget]);

		  swpress:=(((regval and S_Sig.mask_1Bit) xor S_Sig.mask_pol)>0);
		  if swpress then
		  begin // switch is pressed
			if sw1stpress then 
		  	begin	
		      SetTimeOut(dt,sleeptime_ms);	// Retrigger press time	
		      dt2:=now;						// switch pressed start time 
			  sw1stpress:=false;  
		  	end
		  	else 
		  	begin
			  EnterCriticalSection(ENC_CS); 
			  
			  	if TimeElapsed(dt,SwitchRepeatTime_ms) then 
			  	begin
				  inc(CNTInfo.switchcounter);
			  	  sw_change:=true; 
			  	end;
			  	
			  LeaveCriticalSection(ENC_CS); 
		  	end;
		  end else sw1stpress:=true;
		  
		  if sw_change or (swpress and not sw1stpress) then 
			CNTInfo.switchlastpresstime:=MilliSecondsBetween(now,dt2); // last switch press time
		  
		end; 
		delta:=0;	  
		if seq<>seqold then  
		begin // turning wheel
//		  fpc calc neg mod wrong Ex: (−144)%5=5−(144%5)=5−(4)=1(−144)%5=5−(144%5)=5−(4)=1
		  if seqold>seq	then delta:=4-(abs(seq-seqold) mod 4) else delta:=(seq-seqold) mod 4;
		  if delta=3	then delta:=-1
			            else if delta=2 then if deltaold<0 then delta:=-delta; 
		  SetTimeOut(CNTInfo.fIntervalResetTime,CNTInfo.Interval_ms); 
		  EnterCriticalSection(ENC_CS); 
			FREQ_DetTurnRate(CNTInfo.TurnRateStruct,delta); 
			if s2minmax then
			begin
			  if (CNTInfo.counter+delta)<0 then CNTInfo.counter:=0 else inc(CNTInfo.counter,delta);
			  if CNTInfo.counter>(CNTInfo.countermax-1) then CNTInfo.counter:=CNTInfo.countermax-1;
			end
			else begin inc(CNTInfo.counter,delta); end;
//			CNTInfo.counter:=CNTInfo.counter mod CNTInfo.countermax;			// 0 - countermax-1
			CNTInfo.counter:=MOD_Euclid(CNTInfo.counter,CNTInfo.countermax);	// 0 - countermax-1
			CNTInfo.cycles:= CNTInfo.counter div CNTInfo.steps_per_cycle;
		  LeaveCriticalSection(ENC_CS);
//        writeln('Seq:',seq,' seqold:',seqold,' delta:',delta,' deltaold:',deltaold,' b:',b,' a:',a);		  
		  deltaold:=delta; seqold:=seq;
		end else if TimeElapsed(CNTInfo.fIntervalResetTime) then FREQ_CounterReset(CNTInfo.TurnRateStruct);	 
		if (beepgpio>=0) and ((CNTInfo.cycles<>cyclold) or sw_change) then GPIO_Pulse(beepgpio,1);
		delay_msec(sleeptime_ms);
		sw_change:=false; 
	  until ThreadCtrl.TermThread;
//    writeln('ENC_Device: Thread will terminate');
	  DoneCriticalSection(ENC_CS);
	  EndThread;
	  ThreadCtrl.ThreadRunning:=false;
	end; // with
  end else LOG_Writeln(LOG_ERROR,'ENC_Device: hdl '+Num2Str(hdl,0)+' out of range');
  ENC_Device:=0;
end;

procedure ENC_InfoKBDInit(var CNTInfo:ENC_CNT_struct_t; kbdup,kbddwn,kbdsw:char);
begin
  with CNTInfo do
  begin
	kbdcode:=' '; kbdupcnt:=kbdup; kbddwncnt:=kbddwn; kbdswitch:=kbdsw;
  end;
end;

procedure ENC_InfoInit(var CNTInfo:ENC_CNT_struct_t);
begin
  with CNTInfo do
  begin
    Handle:=-1; 		steps_per_cycle:=4;
    ENC_activity:=false;						activitymodedetect:=0;	
    encsteps:=0;		swsteps:=0;				enccycles:=0;			
    counter:=0;			counterold:=0; 			countermax:=$ffff;			
    switchcounter:=0;	switchcounterold:=0;	switchcountermax:=$ffff;	
    enc:=0; 			encold:=0;  			Interval_ms:=1000;
    fIntervalResetTime:=now;					switchlastpresstime:=0;
    ENC_InfoKBDInit		(CNTInfo,#38,#40,#13);
    FREQ_InitStruct		(TurnRateStruct, 250);	
  end; // with
end;

function  ENC_Setup(hdl:integer; stick2minmax:boolean; 
					ctrpreset,ctrmax,stepspercycle:longword; 
					beepergpio:integer):boolean;
//in: 	hdl:			1..ENC_cnt
//		A/B_Sig:		2 GPIOs, which should be used for the Encoder A,B Signal
//      S_Sig:			GPIO, which handles SwitchButton of Encoder. e.g. the KY-040 encoder has a switch. 
//		stick2minmax: 	true,  if we don't want an immediate counter transition from <ctrmax> to 0 or from 0 to <ctrmax>  
//		ctrpreset:		set an initial counter value. multiple of stepspercycle
//		ctrmax:			counter is always between 0 and <ctrmax>
//		stepspercycle:	an regular encoder generates 4 steps per cycle (resolution)
//out:					true, if we could allocate the HW-Pins (success)
var _ok:boolean;
begin
  _ok:=false;
  if (hdl>=0) and (hdl<Length(ENC_struct)) then
  begin
    with ENC_struct[hdl] do
    begin 
	  ok:=(GPIO_Setup(A_Sig) and GPIO_Setup(B_Sig));
	  if S_Sig.gpio>=0 then ok:=ok and GPIO_Setup(S_Sig);
      if ok then 
      begin	// Pins are available
        ENC_InfoInit(CNTInfo);  CNTInfo.Handle:=hdl; 
		s2minmax:=stick2minmax; sleeptime_ms:=ENC_SyncTime_c; 
		SwitchRepeatTime_ms:=ENC_SwRepeatTime_c;
	    seqold:=2; deltaold:=0; SwitchFiredSpecFunc:=nil;
		if stepspercycle>0 then CNTInfo.steps_per_cycle:=stepspercycle;
		CNTInfo.cycles:=round(ctrpreset/CNTInfo.steps_per_cycle);
		idxcounter:=0; beepgpio:=beepergpio; 
		if ((beepgpio>=0) and 
		   (GPIO_MAP_GPIO_NUM_2_HDR_PIN(beepgpio)>=0)) then GPIO_set_output(beepgpio);
		with CNTInfo do
		begin
		  ENC_activity:=false;
		  counter:=(cycles*steps_per_cycle); 
		  counterold:=counter; countermax:=counter+1;
		  if ctrmax>counter then countermax:=ctrmax+1; // wg. counter mod countermax
		end; // with
		ENC_GetCounter(CNTInfo);
//		ThreadCtrl.ThreadID:=BeginThread(@ENC_Device,pointer(hdl)); // Start Encoder Thread
		Thread_Start(ThreadCtrl,@ENC_Device,pointer(hdl),0,-1); // Start Encoder Thread
      end else LOG_Writeln(LOG_ERROR,'ENC_RotEncInit: Checked Pins not ok');
      _ok:=ok;	  
    end; // with
  end
  else 
  if (hdl>ENC_cnt) then LOG_Writeln(LOG_ERROR,'ENC_RotEncInit: increase ENC_Cnt:'+Num2Str(ENC_cnt,0)+' hdl:'+Num2Str(hdl,0));
  ENC_Setup:=_ok;
end;

function  ENC_GetHdl(descr:string):byte;
var devnum:longint;
begin
  SetLength(ENC_struct,Length(ENC_struct)+1);
  devnum:=Length(ENC_struct)-1; 
  SAY(LOG_DEBUG,'ENC_GetHdl devnum:'+Num2Str(devnum,0));
  with ENC_struct[devnum] do
  begin
    desc:=descr;
    ENC_InfoInit(CNTInfo);
	CNTInfo.Handle:=devnum;
  end;
  ENC_GetHdl:=devnum; 
end;

procedure ENC_Test;
// tested with Keyes KY-040 Rotary Encoder
// pls. be aware, that the SWitch Input has no external Pullup. Turn on internal Port-PullUP
// Switch Input has active low signal -> ReversePolarity
const StepsPerRev=4; MAXCount=1024; MAXSWCount=6; term=5;
//    Pins on Connector, where the Encoder is connected to. 
      ENC_A_HWPin=15; ENC_B_HWPin=16; ENC_S_HWPin=18; // A:GPIO22(DT) B:GPIO23(CLK) SW:GPIO24(SW)
var   ENC_hdl:byte; cnt,swcnt:word; dt:TDateTime;
  
begin
  ENC_hdl:=ENC_GetHdl('ENC-Test');// create a Encoder Data-structure. return is a hdl
  with ENC_struct[ENC_hdl] do
  begin
    GPIO_SetStruct(A_Sig,1,GPIO_MAP_HDR_PIN_2_GPIO_NUM(ENC_A_HWPin),'ENC A-Signal (DT)', [INPUT]);
    GPIO_SetStruct(B_Sig,2,GPIO_MAP_HDR_PIN_2_GPIO_NUM(ENC_B_HWPin),'ENC B-Signal (CLK)',[INPUT]);
    GPIO_SetStruct(S_Sig,3,GPIO_MAP_HDR_PIN_2_GPIO_NUM(ENC_S_HWPin),'ENC Switch (SW)',   [INPUT,PullUP,ReversePOLARITY]);
    if ENC_Setup(ENC_hdl,true,0,MAXCount,StepsPerRev,UKN) then
    begin
      cnt:=0; swcnt:=0;
      writeln('Do some manual rotation on encoder. Prog will terminate, if Switch was pressed ',term,' times');
	  writeln('Used Pins on Connector, A-Pin:',A_SIG.HWPin,' B-Pin:',B_SIG.HWPin,' SW-Pin:',S_SIG.HWPin);
	  writeln('Used GPIOs with Signal: A on GPIO',A_SIG.gpio,', B on GPIO',B_Sig.gpio,', SW on GPIO',S_Sig.gpio);
	  writeln('MAXCount:',MAXCount,' MAXSWCount:',MAXSWCount-1);
//    InitCriticalSection(ENC_CS); 
	  SetTimeOut(dt,TestTimeOut_sec*1000);
      repeat // Main Loop
        delay_msec(500);	// wait x millisec, relevant for reporting only
	    swcnt:=round(ENC_GetSwitch(ENC_hdl));
	    writeln( 'Counter: ',	round(ENC_GetVal(ENC_hdl,0)):5,
		  	    ' Cycles: ', 	round(ENC_GetVal(ENC_hdl,1)):5,
			    ' Switch: ',	(swcnt mod MAXSWCount):5,
			    ' PressTime: ',	round(ENC_GetSwPtime(ENC_hdl)):5,		// msec
			    ' TurnRate: ',	ENC_GetVal(ENC_hdl,4):4:0,'Hz' 
			    );  // switch cnt 0..(MAXSWCount-1)
        inc(cnt);
      until (swcnt>=term) or TimeElapsed(dt);  // end, if Encoder Switch was pressed <term> times
//    DoneCriticalSection(ENC_CS);
	  writeln('Encoder Thread will terminate');
	  ENC_End(ENC_hdl);
    end else Log_Writeln(Log_ERROR,'ENC_Test: can not init ENC datastruct');
  end; // with
  writeln('ENC Test end.');
end;

function  TRIG_GetValue(hdl:integer; var timesig_ms:longint):integer;
// out: -1:NO IN signal detected; 0:IN signal active; 
// out:  1:IN signal not active anymore, lastsignaltime in ms
var _res:integer;
begin 
  _res:=-1;
  if (hdl>=0) and (hdl<Length(TRIG_struct)) then
  begin
    with TRIG_struct[hdl] do
    begin
	  EnterCriticalSection(TRIG_CS); 
	    if flg then _res:=0;	// in signal high
	    if ((not flg) and (tim_ms>0)) then _res:=1;	// in signal down
		if _res=1 then begin timesig_ms:=tim_ms; tim_ms:=0; end;
	  LeaveCriticalSection(TRIG_CS); 
    end; // with
  end;
  TRIG_GetValue:=_res;
end;
  
function  TRIG_IN_Thread(ptr:pointer):ptrint;
var _hdl:longint; 
begin 
  _hdl:=longint(ptr);
  if (_hdl>=0) and (_hdl<Length(TRIG_struct)) then
  begin
    with TRIG_struct[_hdl] do
    begin
	  Thread_SetName(desc);  
	  ThreadCtrl.ThreadRunning:=true; ThreadCtrl.TermThread:=false;
//    writeln('ThreadStart ',TermThread,' ',sleeptime_ms); 
	  InitCriticalSection(TRIG_CS); 
	  repeat
        GPIO_Switch(TGPIO); // IN Part: Get HW-Signal and update DataStruct
		with TGPIO do
		begin
	      if ein and (not flg) then 
	      begin
		    EnterCriticalSection(TRIG_CS); 
	          SyncTime:=now; // start time 
		      tim_ms:=0;
		      flg:=true;
		    LeaveCriticalSection(TRIG_CS); 
	      end;
	      if (not ein) and flg then
	      begin
		    EnterCriticalSection(TRIG_CS); 
	          tim_ms:=MilliSecondsBetween(now,SyncTime);
	          flg:=false;
		    LeaveCriticalSection(TRIG_CS); 
	      end;
		  delay_msec(SyncTime_ms);
		end; // with
	  until ThreadCtrl.TermThread;
	  DoneCriticalSection(TRIG_CS);
	end; // with
  end;
  TRIG_IN_Thread:=0;
end;

procedure TRIG_SetValue(hdl:integer; timesig_ms:longint);
begin 
  if (hdl>=0) and (hdl<Length(TRIG_struct)) then
  begin
    with TRIG_struct[hdl] do
    begin
	  EnterCriticalSection(TRIG_CS); 
	    tim_ms:=timesig_ms; flg:=true;
	  LeaveCriticalSection(TRIG_CS); 
    end; // with
  end;
end;

function  TRIG_OUT_Thread(ptr:pointer):ptrint;
var _hdl:longint; 
begin 
  _hdl:=longint(ptr);
  if (_hdl>=0) and (_hdl<Length(TRIG_struct)) then
  begin
    with TRIG_struct[_hdl] do
    begin
	  Thread_SetName(desc);  
	  ThreadCtrl.ThreadRunning:=true; ThreadCtrl.TermThread:=false;
//    writeln('ThreadStart ',TermThread,' ',sleeptime_ms); 
	  InitCriticalSection(TRIG_CS); 
	  repeat
		with TGPIO do
		begin
		  EnterCriticalSection(TRIG_CS); 
	        if (tim_ms>0) then
		    begin
			  GPIO_set_pin(gpio,true);
			  delay_msec(tim_ms);
			  GPIO_set_pin(gpio,false);
		    end;
		    if (tim_ms<0) then
		    begin
			  GPIO_set_pin(gpio,false);
			  delay_msec(abs(tim_ms));
			  GPIO_set_pin(gpio,true);
		    end;
		    tim_ms:=0;		  
		  LeaveCriticalSection(TRIG_CS); 
		  delay_msec(SyncTime_ms);
		end; // with
	  until ThreadCtrl.TermThread;
	  DoneCriticalSection(TRIG_CS);
	end; // with
  end;
  TRIG_OUT_Thread:=0;
end;

procedure TRIG_End(hdl:integer); 
var i:integer; 
begin 
  if (hdl<0) then
  begin
    for i:= 1 to Length(TRIG_struct) do Thread_End(TRIG_struct[i-1].ThreadCtrl,100);
	SetLength(TRIG_struct,0);
  end
  else
  begin
    if (hdl>=0) and (hdl<Length(TRIG_struct)) then Thread_End(TRIG_struct[hdl].ThreadCtrl,100);
  end;
end;
 
function  TRIG_Reg(gpio:longint; descr:string; flags:s_port_flags; synctim_ms:longword):integer;
var _hdl,mode:integer;
begin
  _hdl:=-1;
  if (gpio>=0) then 
  begin
    SetLength(TRIG_struct,Length(TRIG_struct)+1); _hdl:=Length(TRIG_struct)-1; 
    with TRIG_struct[_hdl] do
    begin
      desc:=descr; tim_ms:=0; SyncTime:=now; flg:=false; SyncTime_ms:=synctim_ms; mode:=-1;
	  if (INPUT  IN flags) then mode:=0;
	  if (OUTPUT IN flags) then mode:=1;
	  if mode>=0 then GPIO_SetStruct(TGPIO,1,gpio,desc,flags);
	  case mode of
	    0: if GPIO_Setup (TGPIO)
		     then Thread_Start(ThreadCtrl,@TRIG_IN_Thread, pointer(_hdl),0,-1) 
		     else _hdl:=-1;
	    1: if GPIO_Setup (TGPIO)
		     then Thread_Start(ThreadCtrl,@TRIG_OUT_Thread,pointer(_hdl),0,-1)
		     else _hdl:=-1;
	    else _hdl:=-1;
	  end;
	  if _hdl=-1 then SetLength(TRIG_struct,Length(TRIG_struct)-1);
    end; // with
  end;
  TRIG_Reg:=_hdl;
end;  

procedure TRIG_IN_Test;
const HWPIN=12;
var hdl:integer; timesig_ms:longint;
begin
  RPI_HW_Start([InstSignalHandler]);
  hdl:=TRIG_Reg(GPIO_MAP_HDR_PIN_2_GPIO_NUM(HWPIN),'TrigInTest',[INPUT],TRIG_SyncTime_c);
  if (hdl>=0) then
  begin
    repeat
	  if TRIG_GetValue(hdl,timesig_ms)=1 then
	    writeln('Got a TimeSignal on HWPIN#',HWPIN,' with ',timesig_ms,' msec');
	  delay_msec(1000);	// only for report timing
	until terminateProg;
  end;
end;

procedure Show_Buffer(var data:I2C_databuf_t);
begin
  if LOG_Level<=LOG_DEBUG then LOG_Writeln(LOG_DEBUG,HexStr(data.buf)); 
end;

function rtc_func(fkt:longint; fpath:string; var dattime:TDateTime) : longint;
(* uses e.g. /dev/rtc0 *)
var rslt:integer; hdl:cint; Y,Mo,D,H,Mi,S,MS : Word;
 function rtc_open(fpath:string) : longint; begin {$IFDEF UNIX}rtc_open:=fpOpen(fpath,O_RdWr); {$ENDIF} end;
begin  
  rslt:=0;
  if Pos('/DEV/RTC',Upper(fpath))=1 then 
  begin  
    {$IFDEF UNIX}
    case fkt of
      RTC_RD_TIME  : begin
                         hdl:= rtc_open(fpath);
                         if hdl<0	then begin	LOG_Writeln(LOG_ERROR,'rtc_func #1 RTC_RD_TIME (Handle: '+Num2Str(hdl,0)+')'); exit(hdl); end
                                    else      	LOG_Writeln(LOG_DEBUG,'rtc_func #1 RTC_RD_TIME (Handle: '+Num2Str(hdl,0)+')');          
                         rslt:=fpIOctl(hdl,RTC_RD_TIME, addr(rtc_time));
                         if rslt<0	then begin	LOG_Writeln(LOG_ERROR,'rtc_func #2 RTC_RD_TIME (Handle: '+Num2Str(hdl,0)+') '+LNX_ErrDesc(fpgeterrno)); fpclose(hdl); exit(rslt); end
                                    else    	LOG_Writeln(LOG_DEBUG,'rtc_func #2 RTC_RD_TIME (Handle: '+Num2Str(hdl,0)+')');
                         with rtc_time do
                         begin
                           dattime:=EncodeDateTime(word(tm_year+1900),word(tm_mon+1),word(tm_mday),
                                                   word(tm_hour),     word(tm_min),  word(tm_sec), 0);
                         end;
                         writeln(FormatDateTime('yyyy-mm-dd hh:nn:ss',dattime));
                       end;
        RTC_SET_TIME : begin
                         hdl:= rtc_open(fpath);
                         if hdl < 0    then begin LOG_Writeln(LOG_ERROR,'rtc_func #1 RTC_SET_TIME (Handle: '+Num2Str(hdl,0)+')'); exit(hdl); end
                                       else       LOG_Writeln(LOG_DEBUG,'rtc_func #1 RTC_SET_TIME (Handle: '+Num2Str(hdl,0)+')');
                         with rtc_time do
                         begin
                           DecodeDateTime(dattime,Y,Mo,D,H,Mi,S,MS);
                           tm_year:=Y-1900; tm_mon:=Mo-1; tm_mday:=D; tm_hour:=H; tm_min:=Mi; tm_sec:=S;
                         end;
                         rslt:=fpIOctl(hdl, RTC_SET_TIME, addr(rtc_time));
                         if rslt<0	then begin LOG_Writeln(LOG_ERROR,'rtc_func #2 RTC_SET_TIME (Handle: '+Num2Str(hdl,0)+') '+LNX_ErrDesc(fpgeterrno)); fpclose(hdl); exit(rslt); end
                                    else       LOG_Writeln(LOG_DEBUG,'rtc_func #2 RTC_SET_TIME (Handle: '+Num2Str(hdl,0)+')');
                       end;
      else             rslt:=-1;
    end;
    if rslt=0 then fpclose(hdl);
	{$ENDIF}
  end
  else
  begin
    (* not supported here, must be raw I2C access. Implementation later, maybe. *)
    rslt:=-1;
  end;
  rtc_func:=rslt;
end;

{$IFDEF UNIX}
function  MapUSB(devpath:string):string; // e.g. MapUSB('/dev/ttyUSB0') -> /dev/bus/usb/002/004
var dpath:string; 
begin
  dpath:='echo /dev/bus/usb/`udevadm info --name='+devpath+' --attribute-walk ';
  dpath:=dpath+'| sed -n ''s/\s*ATTRS{\(\(devnum\)\|\(busnum\)\)}==\"\([^\"]\+\)\"/\4/p'' ';
  dpath:=dpath+'| head -n 2 | awk ''{$1 = sprintf("%03d", $1); print}''` ';
  dpath:=dpath+'| tr " " "/"';
//writeln('MapUSB:',dpath);
//echo /dev/bus/usb/`udevadm info --name=/dev/ttyUSB0 --attribute-walk | sed -n 's/\s*ATTRS{\(\(devnum\)\|\(busnum\)\)}==\"\([^\"]\+\)\"/\4/p' | head -n 2 | awk '{$1 = sprintf("%03d", $1); print}'` | tr " " "/"
  call_external_prog(LOG_NONE,dpath,dpath); dpath:=RM_CRLF(dpath);
  if (dpath='')  or   (upper(dpath)='/DEV/BUS/USB/') then dpath:='';
  if (dpath<>'') then if not FileExists(dpath) then dpath:='';
  MapUSB:=dpath;
end;

function  USB_Reset(buspath:string):integer; // call e.g. USB_Reset('/dev/bus/usb/002/004');
var rc,fd,i:integer; devpath:string;
begin
  rc:=-1; 
//writeln('buspath:',buspath,' ',USBDEVFS_RESET);
  if (buspath<>'') then
  begin
    for i:=1 to Anz_Item(buspath,',','') do
	begin
	  devpath:=Select_Item(buspath,',','',i);
      if (devpath='') or (not FileExists(devpath)) then
      begin
        LOG_Writeln(LOG_ERROR,'USB_Reset: no valid device path '+devpath);
      end
      else
      begin
	    fd := fpopen(devpath, O_WRONLY);
	    if (fd < 0) then
	    begin
          LOG_Writeln(LOG_ERROR,'USB_Reset: Error opening device '+devpath);
	    end
	    else
	    begin
          LOG_Writeln(LOG_DEBUG,'USB_Reset: Resetting USB device '+devpath);
	      rc := fpioctl(fd, USBDEVFS_RESET, nil);
	      if (rc<0)	then begin LOG_Writeln(LOG_ERROR,'USB_Reset: Error in ioctl '+LNX_ErrDesc(fpgeterrno)+' '+devpath);    end
	                else begin LOG_Writeln(LOG_DEBUG,'USB_Reset: successful '+Num2Str(rc,0)+' '+devpath); rc:=0; end;
	      fpclose(fd);
	      if rc=0 then delay_msec(2000);
        end;
      end;
    end;
  end;
  USB_Reset:=rc;
end;
{$ELSE}
function  MapUSB(devpath:string):string;     begin MapUSB:='';    end;
function  USB_Reset(buspath:string):integer; begin USB_Reset:=-1; end;
{$ENDIF}

procedure I2C_EnterCriticalSection(busnum:byte); begin EnterCriticalSection(I2C_bus[busnum].I2C_CS); end;
procedure I2C_LeaveCriticalSection(busnum:byte); begin LeaveCriticalSection(I2C_bus[busnum].I2C_CS); end;

procedure I2C_Show_struct(busnum:byte);
begin
  with I2C_buf[busnum] do
  begin
    Log_Writeln(LOG_DEBUG,'I2C Struct[0x'+Hex(busnum,2)+']:');
	Log_Writeln(LOG_DEBUG,' .hdl: '+Num2Str(hdl,0));
	Log_Writeln(LOG_DEBUG,' .buf: 0x'+HexStr(buf)); 
  end;  
end;

procedure I2C_Display_struct(busnum:byte; comment:string);
begin
  LOG_LevelSave; 
  LOG_LEVEL(LOG_DEBUG); 
  Log_Writeln(LOG_Level,comment); 
  I2C_show_struct(busnum); 
  LOG_LevelRestore;
end;

function  I2C_ChkBusAdr(busnum,baseadr:word):boolean; 
var _ok:boolean;
begin 
  _ok:=((busnum<=I2C_max_bus) and (baseadr>=$03) and (baseadr<=$77));
  if not _ok then 
    LOG_Writeln(LOG_ERROR,'I2C_ChkBusAdr['+Hex(busnum,2)+'/0x'+Hex(baseadr,2)+']: not valid');
  I2C_ChkBusAdr:=_ok; 
end; 

function  I2C_GetSpeed(bus:byte):longint;
var _speed_Hz:longint; sh:string;
begin
  {$warnings off}  
  if (bus>=0) and (bus<=1) then
  {$warnings on}  
  begin
// 								 xxd -ps /sys/class/i2c-adapter/i2c-1/of_node/clock-frequency
    _speed_Hz:=RPI_BCM2835_GetNodeValue('/sys/class/i2c-adapter/i2c-'+Num2Str(bus,0)+'/of_node/clock-frequency',sh);
    if _speed_Hz<0 then
    begin // last chance, try dmesg
      call_external_prog(LOG_NONE,'dmesg | grep bcm2708_i2c',sh); 
      sh:=Select_Item(Upper (sh),	'(BAUDRATE','',2);	//  400000)
      sh:=Select_Item(Trimme(sh,4), ')','',1);		//  400000
      if not Str2Num(sh,_speed_Hz) then _speed_Hz:=-1;
    end;
  end else _speed_Hz:=100000;
  I2C_GetSpeed:=_speed_Hz;
end;

function  I2C_GetFuncs(bus:byte):longword;
var funcs:longword;
begin
  funcs:=0;
  with I2C_buf[bus] do
  begin
    if (hdl>=0) then
    begin
	  if fpIOctl(hdl,I2C_FUNCS,@funcs)<0 then LOG_Writeln(LOG_ERROR,'I2C_GetFuncs: '+LNX_ErrDesc(fpgeterrno));
    end;
  end; // with
  I2C_GetFuncs:=funcs;
end;

procedure I2C_ShowFuncs(bus:byte);
var i:integer; sh:string;
begin
  sh:='';
  for i:=0 to 30 do
  begin
    case ((1 shl i) and RPI_I2C_GetFuncs(bus)) of
	  I2C_FUNC_I2C:						sh:=sh+'I2C_FUNC_I2C';
	  I2C_FUNC_10BIT_ADDR:				sh:=sh+'I2C_FUNC_10BIT_ADDR';
	  I2C_FUNC_PROTOCOL_MANGLING:		sh:=sh+'I2C_FUNC_PROTOCOL_MANGLING'; 
  	  I2C_FUNC_SMBUS_PEC:				sh:=sh+'I2C_FUNC_SMBUS_PEC';
  	  I2C_FUNC_NOSTART:					sh:=sh+'I2C_FUNC_NOSTART';
  	  I2C_FUNC_SLAVE:				  	sh:=sh+'I2C_FUNC_SLAVE';
  	  I2C_FUNC_SMBUS_BLOCK_PROC_CALL:	sh:=sh+'I2C_FUNC_SMBUS_BLOCK_PROC_CALL';
  	  I2C_FUNC_SMBUS_QUICK:				sh:=sh+'I2C_FUNC_SMBUS_QUICK';
  	  I2C_FUNC_SMBUS_READ_BYTE:			sh:=sh+'I2C_FUNC_SMBUS_READ_BYTE';
	  I2C_FUNC_SMBUS_WRITE_BYTE:		sh:=sh+'I2C_FUNC_SMBUS_WRITE_BYTE';
	  I2C_FUNC_SMBUS_READ_BYTE_DATA:	sh:=sh+'I2C_FUNC_SMBUS_READ_BYTE_DATA';
	  I2C_FUNC_SMBUS_WRITE_BYTE_DATA:	sh:=sh+'I2C_FUNC_SMBUS_WRITE_BYTE_DATA';
	  I2C_FUNC_SMBUS_READ_WORD_DATA:	sh:=sh+'I2C_FUNC_SMBUS_READ_WORD_DATA'; 
	  I2C_FUNC_SMBUS_WRITE_WORD_DATA:	sh:=sh+'I2C_FUNC_SMBUS_WRITE_WORD_DATA';
	  I2C_FUNC_SMBUS_PROC_CALL:			sh:=sh+'I2C_FUNC_SMBUS_PROC_CALL';
	  I2C_FUNC_SMBUS_READ_BLOCK_DATA:	sh:=sh+'I2C_FUNC_SMBUS_READ_BLOCK_DATA';
	  I2C_FUNC_SMBUS_WRITE_BLOCK_DATA:	sh:=sh+'I2C_FUNC_SMBUS_WRITE_BLOCK_DATA'; 
	  I2C_FUNC_SMBUS_READ_I2C_BLOCK:	sh:=sh+'I2C_FUNC_SMBUS_READ_I2C_BLOCK';
	  I2C_FUNC_SMBUS_WRITE_I2C_BLOCK:	sh:=sh+'I2C_FUNC_SMBUS_WRITE_I2C_BLOCK';
    end;
    sh:=sh+' ';
  end;
  sh:=Trimme(StringReplace(sh,'I2C_FUNC_','',[rfReplaceAll,rfIgnoreCase]),4);
  writeln('I2C_FUNC_ ',sh); 
end;

procedure I2C_CleanBuffer(busnum:byte);
begin with I2C_buf[busnum] do begin hdl:=-1; buf:=''; end; end;

procedure I2C_Start(busnum:integer);
var _I2C_path:string;
begin
  _I2C_path:='';
  with I2C_buf[busnum] do
  begin
    I2C_CleanBuffer(busnum);
    I2C_bus[busnum].I2C_useCS:=false;
    I2C_bus[busnum].I2C_speed:=0;
    I2C_bus[busnum].I2C_funcs:=0;
    {$IFDEF UNIX}
      if RPI_run_on_ARM then 
      begin 
	    _I2C_path:=I2C_path_c+Num2Str(busnum,0);
	    if (_I2C_path<>'') and FileExists(_I2C_path) then hdl:=fpOpen(_I2C_path,O_RdWr);
	    if hdl>=0 then 
	    begin
		 {$R-}
	      I2C_bus[busnum].I2C_useCS:=false;
	      InitCriticalSection(I2C_bus[busnum].I2C_CS);
	      I2C_bus[busnum].I2C_speed:=I2C_GetSpeed(busnum);
	      I2C_bus[busnum].I2C_funcs:=I2C_GetFuncs(busnum);	      
	     {$R+}
      	  if not RPI_I2C_ChkFuncs(busnum,I2C_FUNC_I2C) then
			LOG_Writeln(LOG_ERROR,'I2C_start[0x'+Hex(busnum,2)+']: no I2C_FUNC_I2C');
	    end;
      end;
    {$ENDIF}
    if (hdl<0) and (busnum=RPI_I2C_busgen) then 
      LOG_Writeln(LOG_ERROR,'I2C_start[0x'+hex(busnum,2)+']: '+_I2C_path);
  end; // with
end;

procedure I2C_Start; var b:byte; begin for b:=0 to I2C_max_bus do I2C_Start(b); end;

procedure I2C_End(busnum:integer);
begin
  {$IFDEF UNIX}
    if RPI_run_on_ARM then   
      if I2C_buf[busnum].hdl>=0 then 
      begin
//      DoneCriticalSection(I2C_bus[busnum].I2C_CS); // waits forever
        fpClose(I2C_buf[busnum].hdl);
      end;
  {$ENDIF}
  I2C_buf[busnum].hdl:=-1;
end;

procedure I2C_Close_All; var b:byte; begin for b:=0 to I2C_max_bus do I2C_End(b); end;

function  I2C_bus_read(busnum,baseadr:word; cmds:string; len:byte; errhdl:integer):integer;
var rslt:integer; lgt:byte; test:boolean; info:string;
begin
  rslt:=-1;
 try 
  with I2C_buf[busnum] do
  begin
    if (hdl>=0) then
    begin
      test:=false; lgt:=len;
	  info:='I2C_bus_read[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2);
	  if cmds<>'' then info:=info+'/0x'+HexStr(cmds);
	  info:=info+']: ';
//	  writeln(info+' 0x'+HexStr(cmds));
	  {$warnings off}
      if lgt>SizeOf(buf) then 
      begin
        LOG_Writeln(LOG_ERROR,info+'Length exceed buflgt, got: '+Num2Str(len,0)+' max: '+Num2Str(SizeOf(buf),0));
        lgt:=SizeOf(buf);
      end;
      {$warnings on}
      {$IFDEF UNIX}
//      if hdl<0 then I2C_start(data);
	    {$warnings off}
//		  rslt:=0;
//        rslt:=fpIOctl(hdl,I2C_TIMEOUT,pointer(1)); if rslt<0 then begin LOG_Writeln(LOG_ERROR,'I2C_TIMEOUT: '+LNX_ErrDesc(fpgeterrno)); exit(rslt); end; 
//        rslt:=fpIOctl(hdl,I2C_RETRIES,pointer(2)); if rslt<0 then begin LOG_Writeln(LOG_ERROR,'I2C_RETRIES: '+LNX_ErrDesc(fpgeterrno)); exit(rslt); end;
          rslt:=fpIOctl(hdl,I2C_SLAVE,  pointer(baseadr));
	    {$warnings on}
        if rslt<0 then
        begin
          LOG_Writeln(LOG_ERROR,info+'failed to select device: '+LNX_ErrDesc(fpgeterrno));
          ERR_MGMT_UPD(errhdl,_IOC_NONE,lgt,false);	  
	      buf:='';
		  exit(rslt);
        end;
	    if cmds<>'' then
	    begin
          rslt:=fpWrite(hdl,cmds[1],Length(cmds));
          if rslt<>1 then
          begin
            LOG_Writeln(LOG_ERROR,info+'failed to write Register: '+LNX_ErrDesc(fpgeterrno));
            ERR_MGMT_UPD(errhdl,_IOC_WRITE,lgt,false);
		    buf:='';
			exit(rslt);
          end;
	    end;
		SetLength(buf,1);
        rslt:=fpRead(hdl,buf[1],lgt);
      {$ENDIF}
      if test then I2C_Display_struct(busnum,'I2C_bus_read:');
      if rslt<0 then
      begin
        LOG_Writeln(LOG_DEBUG,info+'failed to read device: '+LNX_ErrDesc(fpgeterrno));
        ERR_MGMT_UPD(errhdl,_IOC_READ,lgt,false);
		buf:='';
      end
      else
      begin
	    SetLength(buf,rslt);
		ERR_MGMT_UPD(errhdl,_IOC_READ,rslt,true);
        if rslt<lgt then
	      LOG_Writeln(LOG_ERROR,info+'Short read, errnum: '+Num2Str(rslt,0)+' expected length: '+Num2Str(lgt,0)+' got: '+Num2Str(rslt,0));
      end;  
    end;
  end; // with
 except
  On E_rpi_hal_Exception :Exception do writeln('I2C_bus_read: ',E_rpi_hal_Exception.Message); 
 end;
  I2C_bus_read:=rslt;
end;

function  I2C_bus_read(busnum,baseadr,basereg:word; len:byte; errhdl:integer):integer;
var cmds:string;
begin 
  if basereg<>I2C_UseNoReg then cmds:=char(byte(basereg)) else cmds:='';
  I2C_bus_read:=I2C_bus_read(busnum,baseadr,cmds,len,errhdl); 
end;

function  I2C_bus_WrRd(busnum,baseadr:word; const WRbuf:string; WRflgs:word; var RDbuf:string; RDflgs:word; RDlen:byte; errhdl:integer):integer;
// https://elixir.bootlin.com/linux/v3.19.8/source/drivers/i2c/i2c-core.c
// https://gist.github.com/JamesDunne/9b7fbedb74c22ccc833059623f47beb7 
// http://home.hiwaay.net/~jeffj1/i2c-bcm2708.c
// https://www.raspberrypi.org/forums/viewtopic.php?f=44&t=15840&hilit=i2c+repeated+start&start=50
// not ready, experimental
// @400khz bus speed, each spacing time betweeen two transfers: ca. 30us
// with (I2C_M_RD or I2C_M_NOSTART) 2.5us 
// without 14us between I2C_M_WR / I2C_M_RD
var rslt,oklen:integer; msgset:I2C_rdwr_ioctl_data_t; iomsgs:array[0..1] of I2C_msg_t;
begin
  try 
	with I2C_buf[busnum] do
	begin
      with msgset do
      begin
    	nmsgs:=					0;
		if (Length(WRbuf)>0) then
	  	begin
	  	  oklen:=				Length(WRbuf);
		  iomsgs[nmsgs].addr:=	baseadr;
		  iomsgs[nmsgs].bptr:=	@WRbuf[1];
		  iomsgs[nmsgs].len:=	oklen;
		  iomsgs[nmsgs].flags:=	I2C_M_WR or (WRflgs and (not I2C_M_RD));
		  inc   (nmsgs);
	  	end;
	  	if (RDlen>0) then
	  	begin
	  	  oklen:=				RDlen;
		  iomsgs[nmsgs].addr:=	baseadr;
		  iomsgs[nmsgs].bptr:=	@buf[1];
		  iomsgs[nmsgs].len:=	oklen;
		  iomsgs[nmsgs].flags:=	I2C_M_RD or RDflgs;	// I2C_M_NOSTART 2.5us // no I2C_M_NOSTART 13us @400khz
		  inc	(nmsgs);
	  	end;
	  	msgs :=					@iomsgs;
	  	if (nmsgs>0) then
	  	begin
		  {$IFDEF UNIX} 
		  	rslt:=fpIOCTL(hdl,	I2C_RDWR,@msgset);
		  {$ELSE}
		  	rslt:=				-1;
		  {$ENDIF}
	  	end else rslt:=			-1;
	  end; // with
	  
      if (rslt<0) then
      begin
    	SetLength(buf,			0);
    	LOG_Writeln(LOG_ERROR,	'I2C_bus_WrRd[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+']: failed to read device: '+LNX_ErrDesc(fpgeterrno));
    	ERR_MGMT_UPD(errhdl,	_IOC_READ, RDlen,		 false);
//		ERR_MGMT_UPD(errhdl,	_IOC_WRITE,Length(WRbuf),false);
      end
      else
      begin
	    SetLength(buf,			RDlen);
		ERR_MGMT_UPD(errhdl,	_IOC_READ, RDlen,		 true);
//		ERR_MGMT_UPD(errhdl,	_IOC_WRITE,Length(WRbuf),true);
		rslt:=					oklen;
      end;
      
      RDbuf:=					buf;
	end; // with
  except
	On E_rpi_hal_Exception 		:Exception do 
	begin
	  LOG_Writeln(LOG_ERROR,	'I2C_bus_WrRd[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+']: exception: '+E_rpi_hal_Exception.Message); 
	  rslt:=					-1;
	end;
  end;
  I2C_bus_WrRd:=				rslt;
end;

procedure  I2C_SwitchCombined(openmode:boolean);
var fd:cint; sh:string;
begin
  {$IFDEF UNIX} 
	fd:=fpOpen(I2C_COMBINED_path_c,O_WRONLY);
	if (fd>=0) then
	begin
      if openmode then sh:='1'+#$0a else sh:='0'+#$0a;
      fpwrite(fd,sh,Length(sh));				
      fpclose(fd);
	end;
  {$ENDIF}
end;

function  I2C_bus_SEGMENTS(var zipdata:I2C_rdwr_zip_data_t):integer;
// http://www.the-cains-group.net/2017_Workshops/Mar17/5_struct_i2c_msg.html
// work in progress, not ready
var rslt:integer; 
begin
  rslt:=-1;
  with zipdata do
  begin 
//	writeln('#:',Length(iomsgs),' ',datlen,' ',I2C_buf[busno].hdl);
	if (msgset.nmsgs>0) then
	begin	
	  if (I2C_buf[busno].hdl>=0) then
	  begin
      {$IFDEF UNIX}
        rslt:=fpIOCTL(I2C_buf[busno].hdl,I2C_RDWR,@msgset);
      {$ENDIF}    
		if rslt<0 then
    	begin
          LOG_Writeln(LOG_ERROR,'I2C_bus_SEGMENTS[0x'+hex(busno,2)+'/0x'+hex(iomsgs[0].addr,2)+']: failed to read device: '+LNX_ErrDesc(fpgeterrno));
          ERR_MGMT_UPD(hdl,_IOC_READ,datlen,false);
		  I2C_buf[busno].buf:='';
    	end
    	else
    	begin
	      SetLength(I2C_buf[busno].buf,datlen); rslt:=datlen;
		  ERR_MGMT_UPD(hdl,_IOC_READ,datlen,true);
    	end;
      end;    
	end else LOG_Writeln(LOG_ERROR,'I2C_bus_SEGMENTS: Length=0');
  end; // with	
  I2C_bus_SEGMENTS:=rslt;
end;
		
procedure I2C_prep_iomsg(var zipdata:I2C_rdwr_zip_data_t; baseadr:word; const WRbuf:string; WRflgs:word; RDflgs:word; RDlen:byte);
begin
  with zipdata do
  begin
  	with msgset do
  	begin
  	
	  if (Length(WRbuf)>0) and (nmsgs<I2C_RDWR_IOCTL_MAX_MSGS) then
	  begin
		with iomsgs[nmsgs] do
		begin
		  addr:=    	baseadr;
		  bptr:=		@WRbuf[1];
		  len:=     	Length(WRbuf);
		  flags:=   	I2C_M_WR or (WRflgs and (not I2C_M_RD));	
		  inc(			nmsgs);
	  	end; // with
	  end;
	  
	  if (RDlen>0) and (nmsgs<I2C_RDWR_IOCTL_MAX_MSGS) then
	  begin
		with iomsgs[nmsgs] do
		begin
		  addr:=    	baseadr;
		  bptr:=	  	@I2C_buf[busno].buf[datlen+1];
		  len:=     	RDlen;
		  flags:=   	I2C_M_RD or RDflgs;
		  inc(datlen,	RDlen);
		  inc(			nmsgs);
	  	end; // with
	  end;	 
	   
	end; // with
  end; // with
end;

procedure I2C_show_ZIPdata(var zipdata:I2C_rdwr_zip_data_t);
var i:integer;
begin
  with zipdata do
  begin
	writeln('datlen:',datlen,' nmsgs:',msgset.nmsgs);
  	for i:=1 to msgset.nmsgs do
  	begin
	  with iomsgs[i-1] do
  	  begin
		writeln((i-1):2,' addr:0x',Hex(addr,2),' ptr:0x',Hex(bptr,8),' len:',Num2Str(len,2),' flags:0x',Hex(flags,4));	
	  end; // with
  	end;
  end; // with
end;	

procedure I2C_init_ZIPdata(var zipdata:I2C_rdwr_zip_data_t; busnum:word; errhdl:integer);
begin
  with zipdata do
  begin
    msgset.msgs:=	@iomsgs[0];
	hdl:=			errhdl;
	busno:=			busnum;
	datlen:=		0;
//	for msgset.nmsgs:=1 to Length(iomsgs) do I2C_prep_iomsg(zipdata,I2C_UseNoReg,I2C_M_RD,0);
	msgset.nmsgs:=	0;
  end; // with
end;

procedure I2C_ZIP_Test;
// work in progress, not ready
const adr=$70; lgt=2;
var rslt:integer; zipdata:I2C_rdwr_zip_data_t; sh:string;
begin
//writeln('Funcs: 0x'+Hex(RPI_I2C_GetFuncs(RPI_I2C_busgen),8)); I2C_ShowFuncs(RPI_I2C_busgen); 
rslt:=I2C_bus_WrRd(RPI_I2C_busgen,adr,'',0, sh,0, lgt,NO_ERRHNDL);
writeln(rslt,' ',HexStr(I2C_buf[RPI_I2C_busgen].buf));
writeln;
delay_msec(1);

  with zipdata do
  begin					
    I2C_init_ZIPdata(zipdata,RPI_I2C_busgen,NO_ERRHNDL);
    I2C_prep_iomsg	(zipdata,adr,'',0,0,lgt);
    I2C_prep_iomsg	(zipdata,adr,'',0,0,lgt); // ERR I2C_bus_SEGMENTS[0x01/0x70]: failed to read device: (95) Operation not supported on transport endpoint
	
	I2C_show_ZIPdata(zipdata);
I2C_SwitchCombined(true);		// combined mode only for bcm270x !!!!!
	rslt:=I2C_bus_SEGMENTS(zipdata);
I2C_SwitchCombined(false);
	writeln('buf['+Num2Str(rslt,2)+']: 0x',HexStr(I2C_buf[RPI_I2C_busgen].buf));
  end; // with
end;

function oldI2C_string_read(busnum,baseadr:word; cmds:string; len:byte; errhdl:integer; var outs:string):integer; 
var rslt:integer; lgt:byte;
begin   
  with I2C_buf[busnum] do
  begin
    lgt:=len; 
    if len>c_max_Buffer then 
    begin
      LOG_Writeln(LOG_ERROR,'I2C_string_read[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+'/0x'+HexStr(cmds)+']: Length exceed buflgt, got: '+Num2Str(len,0)+' max: '+Num2Str(c_max_Buffer,0));
      buf:='';
	  exit(-1);
	  lgt:=c_max_Buffer;
    end;
//  writeln('I2C_string_read1: I2Caddr:0x'+Hex(baseadr,2)+' reg:0x'+HexStr(cmds)+' busnum:0x'+Hex(busnum,2)+' lgt:0x'+Hex(lgt,2));
    rslt:=I2C_bus_read(busnum,baseadr,cmds,lgt,errhdl); 
//  writeln('I2C_string_read2: I2Caddr:0x'+Hex(baseadr,2)+' reg:0x'+HexStr(cmds)+' busnum:0x'+Hex(busnum,2)+' lgt:0x'+Hex(lgt,2)+' rslt:'+Num2Str(rslt,0));  
	outs:=buf;
	oldI2C_string_read:=rslt;
  end; // with
end;
function oldI2C_string_read(busnum,baseadr,basereg:word; len:byte; errhdl:integer; var outs:string):integer;
var cmds:string;
begin
  if basereg<>I2C_UseNoReg then cmds:=char(byte(basereg)) else cmds:='';
  oldI2C_string_read:=oldI2C_string_read(busnum,baseadr,cmds,len,errhdl,outs);
end;

function I2C_string_read(busnum,baseadr,basereg:word; RDlen:byte; errhdl:integer; var RDbuf:string):integer;
var _obuf:string;
begin 
  if (basereg<>I2C_UseNoReg) then _obuf:=char(byte(basereg)) else _obuf:=''; 
  I2C_string_read:=I2C_bus_WrRd(busnum,baseadr,_obuf,0,RDbuf,0,RDlen,errhdl); 
end;

function I2C_string_read(busnum,baseadr:word; const WRbuf:string; RDlen:byte; errhdl:integer; var RDbuf:string):integer;
begin I2C_string_read:=I2C_bus_WrRd(busnum,baseadr,WRbuf,0,RDbuf,0,RDlen,errhdl); end; 

function  I2C_string_write(busnum,baseadr:word; const WRbuf:string; errhdl:integer):integer; 
var _obuf:string; 
begin I2C_string_write:=I2C_bus_WrRd(busnum,baseadr,WRbuf,0,_obuf,0,0,errhdl); end;

function  I2C_string_write(busnum,baseadr,basereg:word; WRbuf:string; errhdl:integer):integer; 
var _obuf:string; 
begin 
  if (basereg<>I2C_UseNoReg) then WRbuf:=char(byte(basereg))+WRbuf; 
  I2C_string_write:=I2C_bus_WrRd(busnum,baseadr,WRbuf,0,_obuf,0,0,errhdl); 
end;

function  I2C_word_read(busnum,baseadr,basereg:word; flip:boolean; errhdl:integer):word; 
// read from the I2C general purpose bus e.g. s:=I2C_string_read($68,$00,7)
var sh:string; w:word;
begin
  w:=0; I2C_string_read(busnum,baseadr,basereg,2,errhdl,sh);
  if Length(sh)>=2 then
  begin
    if flip then w:=word(ord(sh[2]) shl 8) or word(ord(sh[1]))
			else w:=word(ord(sh[1]) shl 8) or word(ord(sh[2]));
  end;
  I2C_word_read:=w;
end;

function  I2C_byte_read(busnum,baseadr,basereg:word; errhdl:integer):byte; 
// read from the I2C general purpose bus e.g. s:=I2C_string_read($68,$00,7)
var b:byte; sh:string;
begin
  I2C_string_read(busnum,baseadr,basereg,1,errhdl,sh);
  if Length(sh)>=1 then b:=ord(sh[1]) else b:=0;
  I2C_byte_read:=b;
end;

function  oldI2C_bus_write(busnum,baseadr:word; errhdl:integer):integer;
var rslt:integer; lgt:byte;
begin
  rslt:=-1; 
 try
  with I2C_buf[busnum] do
  begin
    if (hdl>=0) then
    begin
      lgt:=Length(buf);	
      {$IFDEF UNIX}
//      writeln('i2cwr: 0x'+HexStr(buf)+' ',hdl); 
        {$warnings off} rslt:=fpIOctl(hdl,I2C_SLAVE,pointer(baseadr)); {$warnings on}
        if rslt<0 then
        begin
          LOG_Writeln(LOG_ERROR,'I2C_bus_write[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+']: failed to open device: '+LNX_ErrDesc(fpgeterrno));
          ERR_MGMT_UPD(errhdl,_IOC_NONE,lgt,false);
	      exit(rslt);
        end;
	    rslt:=fpWrite(hdl,buf[1],lgt);
      {$ENDIF}
//    I2C_Display_struct(busnum,'I2C_bus_write:');
      if rslt<0 then
      begin
        LOG_Writeln(LOG_ERROR,'I2C_bus_write[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+']: failed to write to device: '+LNX_ErrDesc(fpgeterrno));
        ERR_MGMT_UPD(errhdl,_IOC_WRITE,lgt,false);
      end
      else
      begin
	    ERR_MGMT_UPD(errhdl,_IOC_WRITE,lgt,true);
        if (rslt<lgt) then
	      LOG_Writeln(LOG_ERROR,'I2C_bus_write[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+']: short write, errnum: '+Num2Str(rslt,0)+' expected: '+Num2Str(lgt+1,0)+' got: '+Num2Str(rslt,0));
      end;
    end;
  end; // with
 except
   On E_rpi_hal_Exception :Exception do writeln('I2C_bus_write: ',E_rpi_hal_Exception.Message); 
 end;
  oldI2C_bus_write:=rslt;
end;

function  oldI2C_string_write(busnum,baseadr:word; datas:string; errhdl:integer):integer; 
begin   
  if length(datas)>=c_max_Buffer then 
  begin
    LOG_Writeln(LOG_ERROR,'I2C_string_write['+Hex(busnum,2)+'/'+Hex(baseadr,2)+'/'+HexStr(datas)+']: data length:'+Num2Str(length(datas),0)+' exceeds buffer size:'+Num2Str(c_max_Buffer,0));
	exit(-1);
  end;	 
  I2C_buf[busnum].buf:=datas; 
  oldI2C_string_write:=oldI2C_bus_write(busnum,baseadr,errhdl); 
end;

function  oldI2C_string_write(busnum,baseadr,basereg:word; datas:string; errhdl:integer):integer;
var _datas:string;
begin
  _datas:=datas; if basereg<>I2C_UseNoReg then _datas:=char(byte(basereg))+_datas;
  oldI2C_string_write:=oldI2C_string_write(busnum,baseadr,_datas,errhdl);
end;
						
function  I2C_word_write(busnum,baseadr,basereg:word; data:word; flip:boolean; errhdl:integer):integer; 
var sh:string;								// e.g: 0x4321
begin
  if flip 	then sh:=char(byte(data))+char(byte(data shr 8))	// 2143
			else sh:=char(byte(data shr 8))+char(byte(data));	// 4321
  I2C_word_write:=I2C_string_write(busnum,baseadr,basereg,sh,errhdl);
end;

function  I2C_word_write(baseadr,basereg:word; data:word; flip:boolean; errhdl:integer):integer;
begin I2C_word_write:=I2C_word_write(RPI_I2C_busgen,baseadr,basereg,data,flip,errhdl); end;

function  I2C_byte_write(busnum,baseadr,basereg:word; data:byte; errhdl:integer):integer; 
begin I2C_byte_write:=I2C_string_write(busnum,baseadr,basereg,char(data),errhdl); end;

procedure eeprom_SetAddr(devaddr:word); begin eeprom_devadr:=devaddr; end;

function  eeprom_write_page(startadr:word; datas:string):integer;
//write a string to the EEPROM @ I2C-Adr 0x50 startaddr 
begin eeprom_write_page:=I2C_string_write(RPI_I2C_bus2nd,eeprom_devadr,startadr,datas,NO_ERRHNDL); end;

function  eeprom_read_page(startadr:word; len:byte; var outs:string):integer;
begin eeprom_read_page:=I2C_string_read(RPI_I2C_bus2nd,eeprom_devadr,startadr,len,NO_ERRHNDL,outs); end;

//https://www.raspberrypi.org/forums/viewtopic.php?p=521067#p521067
function  BT_RFCOMM(chan:word; bindatstart:boolean; btdev,desc:string):boolean;
// http://www.raspberry-projects.com/pi/pi-operating-systems/raspbian/bluetooth/serial-over-bluetooth
//IN: chan: eg. 1
//IN: bindatstart: e.g. true
//IN: btdev: xx:xx:xx:xx:xx:xx
//IN: desc: My Bluetooth Connection 
const fil='/etc/bluetooth/rfcomm.conf';
var ts:TStringList;
begin
  if btdev<>'' then
  begin
    if desc='' then desc:='BT';
	ts:=TStringList.create;
	ts.add('rfcomm'+Num2Str(chan,0)+' {');
	ts.add('  # Automatically bind the device at startup');
	ts.add('  bind '+lower(Bool2YN(bindatstart))+';');
	ts.add('');
	ts.add('  # Bluetooth address of partner device');
	ts.add('  device '+btdev+';');
	ts.add('');
	ts.add('  # RFCOMM channel for the connection');
	ts.add('  channel '+Num2Str(chan,0)+';');
	ts.add('');
	ts.add('  # Description of the connection');
	ts.add('  comment "'+desc+'";');
	ts.add('}');
	StringList2TextFile(fil,ts);
	ts.free;
  end;
  BT_RFCOMM:=(FileExists(fil));
end;

procedure HW_SetInfoStruct(var DeviceStruct:HW_DevicePresent_t; DevTyp:t_IOBusType; BusNr,HWAdr:integer; dsc:string);
begin with DeviceStruct do begin BusNum:=BusNr; HWAddr:=HWAdr; DevType:=DevTyp; descr:=dsc; end; end;

procedure HW_IniInfoStruct(var DeviceStruct:HW_DevicePresent_t);
begin
  HW_SetInfoStruct(DeviceStruct,UnknDev,hdl_unvalid,hdl_unvalid,'');
  with DeviceStruct do begin present:=false; Hndl:=hdl_unvalid; data:=''; end;
end;

function  SPI_HWT(var DeviceStruct:HW_DevicePresent_t; bus,adr,lgt:word; cmds:string; Handle:integer; rv1,nv1,nv2,dsc:string):boolean;
begin
  with DeviceStruct do
  begin
    HW_IniInfoStruct(DeviceStruct);
    HW_SetInfoStruct(DeviceStruct,SPIDev,0,hdl_unvalid,dsc);
    present:=true;		// Dummy, to do !!!!!!!!! read device to determine if it's there
    
    if present  then begin BusNum:=bus; HWaddr:=adr; hndl:=Handle; end;
    SPI_HWT:=present;
  end;
end;

function  I2C_HWT(var DeviceStruct:HW_DevicePresent_t; bus,adr,lgt:word; cmds:string; Handle:integer; rv1,nv1,nv2,dsc:string):boolean;
// I2C HardwareTest. used to determine, device available on i2c bus
// usage e.g. DisplayPresent:=I2C_HWT(RPI_I2C_busnum,LCD_I2C_ADR,#$01,1,'','','LCD');
var _lvl:t_errorlevel; info:string; 
begin
  with DeviceStruct do
  begin
    HW_IniInfoStruct(DeviceStruct); data:=''; present:=false; _lvl:=LOG_ERROR;
    HW_SetInfoStruct(DeviceStruct,I2CDev,rpi_I2C_busgen,i2c_unvalid_addr,dsc);
    info:=dsc+'[0x'+Hex(bus,2)+'/0x'+Hex(adr,2);
    if cmds<>'' then info:=info+'/0x'+HexStr(cmds);
    info:=info+']: ';    
//  writeln('info:',info);
    if I2C_ChkBusAdr(bus,adr) then
    begin
      I2C_string_read(bus,adr,cmds,lgt,NO_ERRHNDL,data); 
      present:=(data<>'');     
      if present 			   then present:=present and (Length(data)= lgt);
      if present and (rv1<>'') then present:=present and (HexStr(data)= rv1); 
      if present and (nv1<>'') then present:=present and (HexStr(data)<>nv1); 
      if present and (nv2<>'') then present:=present and (HexStr(data)<>nv2); 
      if present then 
      begin
    	_lvl:=LOG_NOTICE;
    	BusNum:=bus; HWaddr:=adr; hndl:=Handle;
      end;
      if (data<>'')	then info:=info+'0x'+HexStr(data) else info:=info+'nodata';
      SAY(_lvl,info);
    end;
    I2C_HWT:=present;
  end; // with
end;

function  I2C_HWSpeedT(BusNum,HWaddr,rdlgt:word; loops:longword; cmds,dsc:string):real;
// out: kb/sec
const rdflgs=I2C_M_NOSTART;
var n,cnt,rdcnt,wrcnt:longword; hndl:integer; ok:boolean; tstrt,tende:timespec; r:real; data:string;
begin
  hndl:=ERR_NEW_HNDL(HWaddr,'I2C_HWSpeedT['+dsc+']:',0,0);
  cnt:=0; wrcnt:=Length(cmds); ok:=true;
  clock_gettime(CLOCK_REALTIME,@tstrt);
  for n:=1 to loops do
  begin
	rdcnt:=I2C_bus_WrRd(BusNum,HWaddr,cmds,0,data,rdflgs,rdlgt,hndl);
	{$warnings off}  
	  if (rdcnt>=0) then inc(cnt,rdcnt+wrcnt) else ok:=false;
	{$warnings on}  
  end;
  clock_gettime(CLOCK_REALTIME,@tende);
//writeln('data: ',HexStr(data));
  r:=MicroSecondsBetween(tende,tstrt)/1000;
  if ok and (r>0) then
  begin
// SAY(LOG_WARNING,'I2C_HWSpeedT: cnt:'+Num2Str(cnt,0)+' msec:'+Num2Str(r,0,2)+' #######################');
// 2018-04-16 22:31:13 WRN I2C_HWSpeedT: cnt:1000 msec:102.00 #######################
    r:=(cnt/1024)/(r/1000);	// kB/sec
  end else r:=0;
//if not ok then 
  ERR_Report(hndl);
  I2C_HWSpeedT:=r;
end;

function  I2C_HWSpeedT(var DeviceStruct:HW_DevicePresent_t; lgt:word; loops:longword; cmds,dsc:string):real;
var r:real;
begin
  r:=0;
  with DeviceStruct do
  begin
	if present	then r:=I2C_HWSpeedT(BusNum,HWaddr,lgt,loops,cmds,dsc)
				else LOG_Writeln(LOG_ERROR,'I2C_HWSpeedT[0x'+Hex(BusNum,2)+'/0x'+Hex(HWaddr,2)+']: '+dsc+' not present');
  end; // with
  I2C_HWSpeedT:=r;
end;

procedure I2C_test;
{V1.0 30-JUL-2013
test on cli, is I2C bus working and determine baseaddr of device. 
Newer version of rpi, I2C bus nr 1. older rpi I2Cbus nr 0.
root@rpi# I2Cdetect -y 0
root@rpi# I2Cdetect -y 1        
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:          -- -- -- -- -- -- -- -- -- -- -- -- --
..
60: -- -- -- -- -- -- -- -- 68 -- -- -- -- -- -- --
70: -- -- -- -- -- -- -- --
on 0x68, this is my RTC DS3232m }
  procedure showstr(s:string); begin if s<>'' then writeln(hexstr(s)) else writeln('device is not responding'); end;
const testnr=1;
var s:string;
  procedure test1_rtc;
  begin
    I2C_string_read(RPI_I2C_busgen,$68,$05,2,NO_ERRHNDL,s); showstr(s); // read 2 bytes; I2C device addr = 0x68; StartRegister = 0x05; result: content of reg[5..6] in string s
    I2C_string_write(RPI_I2C_busgen,$68,$05,#$08+#$12,NO_ERRHNDL); // write 08 in reg 0x05 and 12 in reg 0x06 // set month register to 08 and year to 12
    I2C_string_read(RPI_I2C_busgen,$68,$05,2,NO_ERRHNDL,s); showstr(s); // read 2 bytes
    I2C_string_write(RPI_I2C_busgen,$68,$05,#$07+#$13,NO_ERRHNDL); // write 07 in reg 0x05 and 13 in reg 0x06 // restore month and year
    LOG_Level(LOG_DEBUG); 
	I2C_show_struct(RPI_I2C_busgen); 
	LOG_Level(LOG_WARNING);
  end;
  procedure test2_mma7660;
  // chip: accelerometer
  begin
    I2C_string_write  (RPI_I2C_busgen,$4c,$07,#$00,NO_ERRHNDL); 			// write 00 in reg 0x07 
	I2C_string_write  (RPI_I2C_busgen,$4c,$07,#$04,NO_ERRHNDL); 			// write 04 in reg 0x07 
	I2C_string_write  (RPI_I2C_busgen,$4c,$00,#$04,NO_ERRHNDL);
    I2C_string_write  (RPI_I2C_busgen,$4c,$01,#$03,NO_ERRHNDL);
    I2C_string_write  (RPI_I2C_busgen,$4c,$02,#$02,NO_ERRHNDL);	
//  I2C_string_read(RPI_I2C_busgen,$4c,$07,1,NO_ERRHNDL,s); showstr(s); // read 1 byte; I2C device addr=0x4c; Register=0x07; MOdeRegister
	I2C_string_read(RPI_I2C_busgen,$4c,$00,1,NO_ERRHNDL,s); showstr(s); // read 1 byte; I2C device addr=0x4c; Register=0x00; XOUT  
	I2C_string_read(RPI_I2C_busgen,$4c,$01,1,NO_ERRHNDL,s); showstr(s); // read 1 byte; I2C device addr=0x4c; Register=0x01; YOUT  
	I2C_string_read(RPI_I2C_busgen,$4c,$02,1,NO_ERRHNDL,s); showstr(s); // read 1 byte; I2C device addr=0x4c; Register=0x02; ZOUT  
	LOG_Level(LOG_DEBUG); 
	I2C_show_struct(RPI_I2C_busgen); 
	LOG_Level(LOG_WARNING); 
  end;
begin
  case testnr of
    1 : test1_rtc;
	2 : test2_mma7660;
  end; // case
end;

procedure SPI_show_struct(var spi_strct:spi_ioc_transfer_t);
const errlvl=LOG_WARNING;
begin
  with spi_strct do
  begin
    Log_Writeln(errlvl,'SPI Struct:    0x'+Hex(longword(addr(spi_strct)),8)+' struct size: 0x'+Hex(sizeof(spi_strct),4));
    Log_Writeln(errlvl,' .tx_buf_ptr:  0x'+Hex(tx_buf_ptr,8));
    Log_Writeln(errlvl,' .rx_buf_ptr:  0x'+Hex(rx_buf_ptr,8));
    Log_Writeln(errlvl,' .len:           '+Num2Str(len,0));
    Log_Writeln(errlvl,' .speed_hz:      '+Num2Str(speed_hz,0));
    Log_Writeln(errlvl,' .delay_usecs:   '+Num2Str(delay_usecs,0));
    Log_Writeln(errlvl,' .bits_per_word: '+Num2Str(bits_per_word,0));
	Log_Writeln(errlvl,' .cs_change:     '+Num2Str(cs_change,0));
  end;  
end;

procedure SPI_show_bus_info_struct(busnum:byte);
const errlvl=LOG_WARNING;
begin
  with spi_bus[busnum] do
  begin
    Log_Writeln(errlvl,'SPI Bus Info['+Num2Str(busnum,0)+']:');
	Log_Writeln(errlvl,' .spi_maxspeed:    '+Num2Str(spi_maxspeed,0));
  end;
end;

procedure SPI_show_dev_info_struct(busnum,devnum:byte);
const errlvl=LOG_WARNING;
begin
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    with spi_dev[busnum,devnum] do
    begin
      Log_Writeln(errlvl,'SPI Dev Info['+Num2Str(busnum,0)+'/'+Num2Str(devnum,0)+']:');
      Log_Writeln(errlvl,' .spi_path:      '+spi_path);
	  Log_Writeln(errlvl,' .spi_open:      '+Bool2Str(spi_fd>=0));
	  Log_Writeln(errlvl,' .spi_bpw:       '+Num2Str(spi_bpw,0));
      Log_Writeln(errlvl,' .spi_delay:     '+Num2Str(spi_delay,0));
      Log_Writeln(errlvl,' .spi_speed:     '+Num2Str(spi_speed,0));
	  Log_Writeln(errlvl,' .spi_cs_change: '+Num2Str(spi_cs_change,0));
      Log_Writeln(errlvl,' .spi_LSB_FIRST: '+Num2Str(spi_LSB_FIRST,0));
      Log_Writeln(errlvl,' .spi_mode:      '+Num2Str(spi_mode,0));
      Log_Writeln(errlvl,' .spi_IOC_mode:0x'+Hex(spi_IOC_mode,8));
 //   Log_Writeln(errlvl,' .dev_GPIO_int:  '+Num2Str(dev_GPIO_int,0));
      Log_Writeln(errlvl,' .dev_GPIO_en:   '+Num2Str(dev_GPIO_en,0));
	  Log_Writeln(errlvl,' .dev_GPIO_ook:  '+Num2Str(dev_GPIO_ook,0));
   end; // with
 end else Log_Writeln(Log_ERROR,'SPI_show_dev_info_struct: busnum/devnum out of range');
end; 

procedure SPI_show_buffer(busnum,devnum:byte);
const errlvl=LOG_INFO; maxshowbuf=35;
var i,eidx:longint; sh:string;
begin
  with spi_buf[busnum,devnum] do
  begin
    eidx:=endidx; if eidx>maxshowbuf then eidx:=maxshowbuf; // just show the beginning of the buffer
    SAY(errlvl,'SPI Buffer['+Num2Str(busnum,0)+'/'+Num2Str(devnum,0)+']:');
    SAY(errlvl,' .reg:         0x'+Hex(reg,4));
    if (posidx<=eidx) and (eidx>0) then
    begin
	  sh:=' .buf['+Num2Str(posidx,2)+'..'+Num2Str(eidx,2)+']:  0x';
      for i:= posidx to (eidx+1)*2 do sh:=sh+Hex(ord(buf[i]),2); sh:=sh+' ... ';                                                              
      for i:= posidx to (eidx+1) do sh:=sh+StringPrintable(buf[i]);
      SAY(errlvl,sh);
    end
    else
    begin
      SAY(errlvl,' .buf:           <empty>');
    end;
    SAY(errlvl,' .posidx:        '+Num2Str(posidx,0));
    SAY(errlvl,' .endidx:        '+Num2Str(endidx,0));
  end;
end;

function  _IOC(dir:byte; typ:char; nr,size:word):longword;
{ source http://www.cs.fsu.edu/~baker/devices/lxr/http/source/linux/include/asm-i386/ioctl.h?v=2.6.11.8
         http://lkml.indiana.edu/hypermail/linux/kernel/0108.2/0125.html
		  |dd|ssssssssssssss|tttttttt|nnnnnnnn|
}
begin
  _ioc:=(dir      shl _IOC_DIRSHIFT)  or		// dir  shl 30
        (ord(typ) shl _IOC_TYPESHIFT) or		// typ 	shl  8
        (nr       shl _IOC_NRSHIFT)   or		// nr  	shl  0
        (size     shl _IOC_SIZESHIFT); 			// size shl 16
end;
 
function  _IO  (typ:char; nr:word):longword;      begin _IO  :=_IOC(_IOC_NONE,                typ,nr,0);         end;
function  _IOR (typ:char; nr,size:word):longword; begin _IOR :=_IOC(_IOC_Read,                typ,nr,size);      end;
function  _IOW (typ:char; nr,size:word):longword; begin _IOW :=_IOC(_IOC_Write,               typ,nr,size);      end;
function  _IOWR(typ:char; nr,size:word):longword; begin _IOWR:=_IOC((_IOC_Write or _IOC_Read),typ,nr,size);      end;

function  SPI_GetSpeed(bus:byte):longint;
var _speed_Hz:longint; sh:string;
begin
  {$warnings off}  
  if (bus>=0) and (bus<=1) then
  {$warnings on}  
  begin
    _speed_Hz:=RPI_BCM2835_GetNodeValue('/sys/class/spidev/spidev0.'+Num2Str(bus,0)+'/device/of_node/spi-max-frequency',sh);
//	writeln('SPI_GetSpeed',bus,' ',_speed_Hz);
    if _speed_Hz<=0 then _speed_Hz:=spi_speed_c;
  end else _speed_Hz:=spi_speed_c;
  SPI_GetSpeed:=_speed_Hz;
end;

function SPI_ClockDivider(spi_hz:real):word;
// Clock Divider // SCLK = Core Clock / CDIV // page 156
var cdiv:word; lw:longword; coreclk:real;
begin
  coreclk:=CLK_GetFreq(5);
  if (spi_hz<(coreclk/2)) then
  begin
    cdiv:=0;
	if (spi_hz>0) then
    begin // CDIV must be a power of two. Odd numbers rounded down.
      lw:=RoundUpPow2(DivRoundUp(coreclk,spi_hz));
	  if (lw<=$ffff) then cdiv:=word(lw) else cdiv:=0 // 0 is the slowest we can go
    end;
  end else cdiv:=2; // coreclk/2 is the fastest we can go
  SPI_ClockDivider:=cdiv;
end;

function SPI_GetFreq(spi_hz:real):longword; 
var cdiv:longword;
begin 
  cdiv:=SPI_ClockDivider(spi_hz);
  if cdiv=0 then cdiv:=$10000;	// handle slowest
  SPI_GetFreq:=round(CLK_GetFreq(5)/cdiv);
end;

function  SPI_ClkWrite(spi_hz:real):longword;
//https://github.com/raspberrypi/linux/blob/rpi-4.9.y/drivers/spi/spi-bcm2835.c
var cdiv:word; hz:longword;
begin
  cdiv:=SPI_ClockDivider(spi_hz);
  hz:=SPI_GetFreq(spi_hz);
  SAY(LOG_INFO,'SPI_ClkWrite: '+Num2Str((hz/1000),0,0)+'kHz cdiv:0x'+Hex(cdiv,4)+' cdivold:0x'+Hex(BCM_GETREG(SPI0_CLK),8));
  BCM_SETREG(SPI0_CLK,cdiv,false,false);
  SPI_ClkWrite:=hz;
end;

function SPI_MSGSIZE(n:byte):word; 
var siz:word;
begin 
  if n*SizeOf(spi_ioc_transfer_t)<(1 shl _IOC_SIZEBITS) then 
    siz:=n*SizeOf(spi_ioc_transfer_t) else siz:=0;
  SPI_MSGSIZE:=siz;
end;

function  SPI_IOC_MESSAGE(n:byte):longword; 
begin SPI_IOC_MESSAGE:=_IOW(SPI_IOC_MAGIC,0,SPI_MSGSIZE(n)); end;

function  SPI_Mode(spifd:cint; mode:longword; pvalue:pointer):integer;
var rslt:integer;
begin
  rslt:=-1; {$IFDEF UNIX} if spifd>=0 then rslt:=fpioctl(spifd,mode,pvalue); {$ENDIF}   
  if rslt<0 then Log_Writeln(LOG_ERROR,'SPI_Mode Mode: 0x'+Hex(mode,8)+' spifd:'+Num2Str(spifd,0)+' err:'+LNX_ErrDesc(fpgeterrno));
  SPI_Mode:=rslt;
end;

procedure SPI_EnterCriticalSection(busnum:byte); begin EnterCriticalSection(SPI_bus[busnum].SPI_CS); end;
procedure SPI_LeaveCriticalSection(busnum:byte); begin LeaveCriticalSection(SPI_bus[busnum].SPI_CS); end;

procedure SPI_SetDevErrHndl(busnum,devnum:byte; errhdl:integer);
begin spi_dev[busnum,devnum].errhndl:=errhdl; end;

procedure SPI_Struct_Init(busnum,devnum:byte; var spi_struct:spi_ioc_transfer_t; rx_bufptr,tx_bufptr:pointer; xferlen:longword);
begin
//Log_Writeln(LOG_DEBUG,'SPI_Struct_Init');
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    with spi_dev[busnum,devnum] do
    begin
      with spi_struct do
      begin
        {$warnings off}
          rx_buf_ptr	:= qword(rx_bufptr);
          tx_buf_ptr	:= qword(tx_bufptr);
	    {$warnings on}
        delay_usecs		:= spi_delay;
        speed_hz    	:= spi_speed;
        bits_per_word	:= spi_bpw;
	    cs_change		:= spi_cs_change;	
	    len				:= xferlen; 
	    pad				:= 0;
	    tx_nbits		:= 0;
	    rx_nbits		:= 0;
	    if ((spi_mode and SPI_TX_QUAD)<>0)
	      then tx_nbits:=4
	      else if ((spi_mode and SPI_TX_DUAL)<>0) then tx_nbits:=2;
	    if ((spi_mode and SPI_RX_QUAD)<>0)
	      then rx_nbits:=4
	      else if ((spi_mode and SPI_RX_DUAL)<>0) then rx_nbits:=2;  
		if ((spi_mode and SPI_LOOP)<>0) then
		begin
			if ((spi_mode and SPI_TX_DUAL)<>0) then spi_mode:=spi_mode or SPI_RX_DUAL;
			if ((spi_mode and SPI_TX_QUAD)<>0) then spi_mode:=spi_mode or SPI_RX_QUAD;
		end;    
	    if len>=SPI_BUF_SIZE_c then len:=SPI_BUF_SIZE_c-1;
      end; // with
	  with spi_buf[busnum,devnum] do
	  begin
	    reg:=0; endidx:=0; posidx:=1;
	  end; // with
    end; // with
  end else LOG_Writeln(LOG_ERROR,'SPI_Struct_Init: busnum/devnum not in range');
end;

procedure IO_Init_Const;
begin
  USBDEVFS_RESET:=				_IO  ('U',			20);
  SPI_IOC_RD_MODE:=				_IOR (SPI_IOC_MAGIC, 1, 1);
  SPI_IOC_WR_MODE:=				_IOW (SPI_IOC_MAGIC, 1, 1);
  SPI_IOC_RD_LSB_FIRST:=		_IOR (SPI_IOC_MAGIC, 2, 1);
  SPI_IOC_WR_LSB_FIRST:=		_IOW (SPI_IOC_MAGIC, 2, 1);
  SPI_IOC_RD_BITS_PER_WORD:=	_IOR (SPI_IOC_MAGIC, 3, 1);
  SPI_IOC_WR_BITS_PER_WORD:=	_IOW (SPI_IOC_MAGIC, 3, 1);
  SPI_IOC_RD_MAX_SPEED_HZ:=		_IOR (SPI_IOC_MAGIC, 4, 4);	// SizeOf(longint) ??
  SPI_IOC_WR_MAX_SPEED_HZ:=		_IOW (SPI_IOC_MAGIC, 4, 4); // SizeOf(longint) ??
//RTC_RD_TIME :=			  	_IOR ('p', 		     9, SizeOf(rtc_time_t));
//RTC_SET_TIME:=			  	_IOW ('p', 		    10, SizeOf(rtc_time_t));
  IOCTL_TAG_PROPERTY:=			_IOWR('d',			 0, 4); // SizeOf(longint) ??
  WDIOC_SETTIMEOUT:=			_IOWR('W',			 6, SizeOf(longint));
  WDIOC_GETTIMEOUT:=			_IOR ('W',			 7, SizeOf(longint));
  WDIOC_KEEPALIVE:=				_IOR ('W',			 5, SizeOf(longint));
  WDIOC_GETBOOTSTATUS:=			_IOR ('W',			 2, SizeOf(longint));
  WDIOC_GETSTATUS:=				_IOR ('W',			 1, SizeOf(longint));
  WDIOC_GETSUPPORT:=			_IOR ('W',			 0, SizeOf(watchdog_info_t));
end;

function  SPI_Transfer(busnum,devnum:byte; cmdseq:string):integer;
// http://www.netzmafia.de/skripten/hardware/RasPi/RasPi_SPI.html
const numxfer=1;
var rslt,xlen:integer; xfer:array[0..(numxfer-1)] of spi_ioc_transfer_t; 
begin
  rslt:=-1; xlen:=Length(cmdseq); 
 try
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    if xlen>0 then
    begin
      if xlen>=SPI_BUF_SIZE_c then 
      begin 
        xlen:=SPI_BUF_SIZE_c; 
	    LOG_WRITELN(LOG_ERROR,'spi_transfer: transfer length to long'); 
      end;
      with spi_buf[busnum,devnum] do
      begin
        SPI_Struct_Init(busnum,devnum,xfer[0],addr(buf[1]),addr(buf[1]),xlen); 
        buf:=copy(cmdseq,1,xlen); endidx:=xlen;
//		SPI_show_buffer(busnum,devnum);
//      SPI_Show_Struct(xfer[0]);
        {$IFDEF UNIX} 
          rslt:=fpioctl(spi_dev[busnum,devnum].spi_fd,SPI_IOC_MESSAGE(numxfer),addr(xfer[0])); 
        {$ENDIF}
        if rslt<0 then 
        begin
	      buf:='';
          Log_Writeln(LOG_ERROR,	
		    'SPI_transfer['+Num2Str(busnum,0)+'/'+Num2Str(devnum,0)+'/fd:'+Num2Str(spi_dev[busnum,devnum].spi_fd,0)+']: '+
		    'cmdseq: 0x'+HexStr(cmdseq)+' '+
		    LNX_ErrDesc(fpgeterrno));
	      ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_WRITE,xlen,false);
        end
        else 
	    begin
	      posidx:=1; endidx:=rslt; SetLength(buf,rslt);
	      ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_READ, rslt,true);
	      ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_WRITE,rslt,true);
	    end;
      end; // with
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_Transfer[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
 except
   On E_rpi_hal_Exception :Exception do writeln('SPI_Transfer: ',E_rpi_hal_Exception.Message); 
 end;
  SPI_Transfer:=rslt;
end;

function  SPI_Write(busnum,devnum:byte; basereg,data:word):integer;
var rslt:integer; xfer:spi_ioc_transfer_t; buf:array[0..1] of byte;
begin
  rslt:=-1; 
Log_Writeln(LOG_WARNING,'SPI_write Reg: 0x'+Hex(basereg,4)+' Data: 0x'+Hex(data,4));
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    SPI_Struct_Init(busnum,devnum,xfer,addr(buf),addr(buf),2);
    buf[1]:=byte(data); buf[0]:=byte(basereg);
    {$IFDEF UNIX} 
      rslt:=fpioctl(spi_dev[busnum,devnum].spi_fd,SPI_IOC_MESSAGE(1),addr(xfer)); 
    {$ENDIF}
    if rslt<0 then 
    begin
      ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_WRITE,2,false);
     Log_Writeln(LOG_ERROR,'SPI_write '+Num2Str(rslt,0)+
                          ' devnum: ' +Num2Str(devnum,0)+
                          ' spi_busnum: '+Num2Str(busnum,0)+' '+
                          LNX_ErrDesc(fpgeterrno));
    end
    else
    begin
    writeln('SPI_WRITE: result',rslt);
      ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_WRITE,2,true);
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_Write[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
  SPI_Write:=rslt;
end;

function SPI_Read(busnum,devnum:byte; basereg:word):byte;
var b:byte; rslt:integer; xfer:array[0..1] of spi_ioc_transfer_t; xbuf:SPI_databuf_t;
begin
  rslt:=-1; b:=$ff;
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    SPI_Struct_Init(busnum,devnum,xfer[0],addr(xbuf.buf[1]),addr(xbuf.buf[1]),1);
    SPI_Struct_Init(busnum,devnum,xfer[1],addr(xbuf.buf[1]),addr(xbuf.buf[1]),1);
    for b:=1 to SPI_BUF_SIZE_c do xbuf.buf[b]:=#$00;
	xbuf.buf[1]:=char(byte(basereg)); 
    {$IFDEF UNIX} 
      rslt:=fpioctl(spi_dev[busnum,devnum].spi_fd,SPI_IOC_MESSAGE(2),addr(xfer)); 
    {$ENDIF}
    if rslt<0 then
    begin
	  b:=$ff;
//    Log_Writeln(LOG_ERROR,'SPI_read Reg: 0x'+Hex(reg,4)+' err: '+LNX_ErrDesc(fpgeterrno));
	  ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_READ,1,false);
    end
    else 
    begin 
	  SetLength(xbuf.buf,rslt);
      b:=byte(xbuf.buf[1]); 
//    Log_Writeln(LOG_ERROR,'SPI_read Reg: 0x'+Hex(basereg,4)+' Data: 0x'+HexStr(xbuf.buf)+' rslt:'+Num2Str(rslt,0));
      ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_READ,1,true);	
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_Read[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
  SPI_Read:=b;
end;

function  SPI_BurstRead(busnum,devnum:byte):byte;
{ get byte from Buffer. Buffer was filled before with procedure SPI_BurstRead2Buffer }
var b:byte;
begin
  b:=$ff;
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    if spi_buf[busnum,devnum].posidx<=spi_buf[busnum,devnum].endidx then 
    begin
      b:=ord(spi_buf[busnum,devnum].buf[spi_buf[busnum,devnum].posidx]);
    end;
    inc(spi_buf[busnum,devnum].posidx);
  end else LOG_Writeln(LOG_ERROR,'SPI_BurstRead[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
  SPI_BurstRead:=b;
end;

procedure SPI_BurstRead2Buffer(busnum,devnum,basereg:byte; len:longword);
{ full duplex, see example spidev_fdx.c}
var rslt:integer; xfer : array[0..1] of spi_ioc_transfer_t;
begin
//  Log_Writeln(LOG_DEBUG,'SPI_BurstRead2Buffer devnum:0x'+Hex(devnum,4)+' reg:0x'+Hex(start_reg,4)+' len:0x'+Hex(len,8));
  rslt:=-1;
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    if spi_buf[busnum,devnum].posidx>spi_buf[busnum,devnum].endidx then
    begin
      SPI_Struct_Init(busnum,devnum,xfer[0],addr(spi_buf[busnum,devnum].buf),addr(spi_buf[busnum,devnum].buf),1);
	  SPI_Struct_Init(busnum,devnum,xfer[1],addr(spi_buf[busnum,devnum].buf),addr(spi_buf[busnum,devnum].buf),len);
      spi_buf[busnum,devnum].buf[1]:=char(byte(basereg)); 
	  spi_buf[busnum,devnum].reg:=basereg;
//    SPI_SetMode(busnum,devnum);
  (*  if LOG_GetLogLevel<=LOG_DEBUG then show_spi_struct(xfer[0]);
	  if LOG_GetLogLevel<=LOG_DEBUG then show_spi_struct(xfer[1]);
 	  if LOG_GetLogLevel<=LOG_DEBUG then show_spi_dev_info_struct(busnum,devnum); *)

//    Log_Writeln(LOG_DEBUG,'fpioctl('+Num2Str(spi_bus[busnum].spi_fd,0)+', 0x'+Hex(SPI_IOC_MESSAGE(2),8)+', 0x'+Hex(longword(addr(xfer)),8)+')'); 
      {$IFDEF UNIX}
	    rslt:=fpioctl(spi_dev[busnum,devnum].spi_fd,SPI_IOC_MESSAGE(2),addr(xfer)); { full duplex }
      {$ENDIF} 
      if rslt<0 then 
	  begin
//	    Log_Writeln(LOG_ERROR,'SPI_BurstRead2Buffer fpioctl err: '+LNX_ErrDesc(fpgeterrno));
        spi_buf[busnum,devnum].endidx:=0;
        spi_buf[busnum,devnum].posidx:=1;
	  end
	  else
	  begin
        spi_buf[busnum,devnum].endidx:=rslt; 
        spi_buf[busnum,devnum].posidx:=1;
	  end;
//	  if LOG_Get_Level<=LOG_DEBUG then show_spi_buffer(spi_buf[devnum]);
	  (* if LOG_GetLogLevel<=LOG_DEBUG then show_spi_struct(rfm22_stat[devnum]); *)
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_BurstRead2Buffer[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
//  Log_Writeln(LOG_DEBUG,'SPI_BurstRead2Buffer (end)');
end;

procedure SPI_BurstWriteBuffer(busnum,devnum,basereg:byte; len:longword);
// Write 'len' Bytes from Buffer SPI Dev startig at address 'reg'
var rslt:integer; xfer : spi_ioc_transfer_t;
begin
//  Log_Writeln(LOG_DEBUG,'SPI_BurstWriteBuffer devnum:0x'+Hex(devnum,4)+' reg:0x'+Hex(start_reg,4)+' xferlen:0x'+Hex(xferlen,8));
  rslt:=-1;
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    if len>0 then
    begin
      SPI_Struct_Init(busnum,devnum,xfer,addr(spi_buf[busnum,devnum].buf),addr(spi_buf[busnum,devnum].reg),len+1); //+1 Byte, because send reg-content also. transfer starts at addr(spi_buf[devnum].reg)
      spi_buf[busnum,devnum].reg:=basereg;
//    SPI_SetMode(busnum,devnum);
// 	  if LOG_Get_Level<=LOG_DEBUG then show_spi_struct(xfer);
// 	  if LOG_Get_Level<=LOG_DEBUG then show_spi_dev_info_struct(busnum,devnum);
// 	  if LOG_Get_Level<=LOG_DEBUG then show_spi_buffer(busnum,devnum);
// 	  if LOG_Get_Level<=LOG_DEBUG then Log_Writeln(LOG_DEBUG,'fpioctl('+Num2Str(spi_bus[busnum].spi_fd,0)+', 0x'+Hex(SPI_IOC_MESSAGE(1),8)+', 0x'+Hex(longword(addr(xfer)),8)+')'); 
	  {$IFDEF UNIX}
	    rslt:=fpioctl(spi_dev[busnum,devnum].spi_fd,SPI_IOC_MESSAGE(1),addr(xfer)); 
	  {$ENDIF}
      if rslt<0 then Log_Writeln(LOG_ERROR,'SPI_BurstWriteBuffer fpioctl err: '+LNX_ErrDesc(fpgeterrno))
	            else inc(spi_buf[busnum,devnum].posidx,rslt-1); //rslt-1 wg. reg + buffer content
//	  if LOG_Get_Level<=LOG_DEBUG then show_spi_buffer(busnum,devnum);
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_BurstWriteBuffer[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
end;

procedure SPI_StartBurst(busnum,devnum:byte; reg:word; writeing:byte; len:longint);
begin
//Log_Writeln(LOG_DEBUG,'StartBurst StartReg: 0x'+Hex(reg,4)+' writing: '+Bool2Str(writeing<>0));
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    if (spi_dev[busnum,devnum].spi_fd>=0) then 
    begin
//    SPI_SetMode(busnum,devnum);
	  spi_buf[busnum,devnum].reg:=byte(reg);
      if writeing=1 then 
	  begin
	    spi_buf[busnum,devnum].endidx:=len; spi_buf[busnum,devnum].posidx:=1; 
	    SPI_BurstWriteBuffer(busnum,devnum,reg,len); { Write 'len' Bytes from Buffer to SPI Dev startig at address 'reg'  }
	    if ((reg and $7f)=$7f) then SPI_write(busnum,devnum,$3e,word(len)); { set packet length for TX FIFO }
      end
	  else 
	  begin
	    spi_buf[busnum,devnum].endidx:=0; 
	    spi_buf[busnum,devnum].posidx:=1;  { initiate BurstRead2Buffer }
	    SPI_BurstRead2Buffer(busnum,devnum,reg,len);  { Read 'len' Bytes from SPI Dev to Buffer }
	    //inc(spi_buf[busnum,devnum].posidx); //1. Byte in Read Buffer is startregister -> position to 1. register content 
	  end;
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_StartBurst[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
end;

procedure SPI_EndBurst(busnum,devnum:byte);
begin
//Log_Writeln(LOG_DEBUG,'SPI_EndBurst');
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    spi_buf[busnum,devnum].endidx:=0; 
    spi_buf[busnum,devnum].posidx:=1; // initiate BurstRead2Buffer
  end else LOG_Writeln(LOG_ERROR,'SPI_EndBurst[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
end;

function  xxSPI_Dev_Init(busnum,devnum:byte):boolean;
var ok:boolean;
begin
  ok:=false;
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    with spi_dev[busnum,devnum] do 
    begin 
	  errhndl		:= NO_ERRHNDL;
	  isr_enable	:= false;
	  isr.gpio		:= -1;
	  spi_LSB_FIRST	:= 0;
	  spi_bpw		:= 8;
      spi_delay		:= 0;
	  spi_cs_change	:= 0;	// do not change CS during multiple byte transfers
	  spi_speed		:= SPI_GetSpeed(busnum); 
      spi_mode		:= SPI_MODE_0;
	  spi_IOC_mode	:= SPI_IOC_RD_MODE; 
	  spi_fd		:= -1; 
	  spi_path		:=spi_path_c+Num2Str(busnum,0)+'.'+Num2Str(devnum,0);
//writeln('SPI_Dev_Init: ',spi_path);
	  if (spi_path<>'') and FileExists(spi_path) then
      begin
	    {$IFDEF UNIX} spi_fd:=fpOpen(spi_path,O_RdWr); {$ENDIF}
      end;
	  if (spi_fd<0) then 
	  begin
	    Log_Writeln(LOG_ERROR,'SPI_Dev_Init[0x'+Hex(busnum,2)+'/'+Hex(devnum,2)+']: '+spi_path);
	    if LOG_Level<=LOG_DEBUG then SPI_show_dev_info_struct(busnum,devnum);
	  end
	  else ok:=true;
    end; // with
  end else LOG_Writeln(LOG_ERROR,'SPI_Dev_Init[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
//SPI_show_dev_info_struct(spi_dev[devnum], devnum);
  xxSPI_Dev_Init:=ok;
end;

function  SPI_Dev_Init(busnum,devnum,bpw,cs_change:byte; mode,maxspeed_hz:longword; delay_usec:word):boolean;
var ok:boolean; res:integer; 
begin
  ok:=false;
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    with spi_dev[busnum,devnum] do 
    begin 
	  errhndl		:= NO_ERRHNDL;
	  isr_enable	:= false;
	  isr.gpio		:= -1;
	  spi_bpw		:= bpw;
      spi_delay		:= delay_usec;
      if cs_change<>0  then spi_cs_change:=1 else spi_cs_change:=0;     
	  spi_speed		:= maxspeed_hz;
      spi_mode		:= mode;
	  spi_IOC_mode	:= SPI_IOC_RD_MODE; 
	  spi_path		:=spi_path_c+Num2Str(busnum,0)+'.'+Num2Str(devnum,0);
//writeln('SPI_Dev_Init: ',spi_path,' speed:',(spi_speed div 1000),'kHz');
	  if (spi_path<>'') and FileExists(spi_path) then
      begin
	    {$IFDEF UNIX} 
	      if spi_fd<0 then spi_fd:=fpOpen(spi_path,O_RdWr); 	 
		  res:=fpioctl(spi_fd,SPI_IOC_WR_MODE,@spi_mode);
		  if (res=-1) then Log_Writeln(Log_ERROR,'SPI_Dev_Init: can''t set SPI mode 0x'+Hex(spi_mode,8)+' '+LNX_ErrDesc(fpgeterrno));   	      	      
	      res:=fpioctl(spi_fd,SPI_IOC_WR_BITS_PER_WORD,@spi_bpw);
		  if (res=-1) then Log_Writeln(Log_ERROR,'SPI_Dev_Init: can''t set bits per word '+Num2Str(spi_bpw,0)+' '+LNX_ErrDesc(fpgeterrno));            
		  res:=fpioctl(spi_fd,SPI_IOC_WR_MAX_SPEED_HZ,@spi_speed);
          if (res=-1) then Log_Writeln(Log_ERROR,'SPI_Dev_Init: can''t set max speed '+Num2Str(spi_speed,0)+'hz '+LNX_ErrDesc(fpgeterrno));	  
 		  {$RANGECHECKS OFF}		  
 		    res:=fpioctl(spi_fd,SPI_IOC_RD_MODE,@spi_mode); 
		    if (res=-1) then Log_Writeln(Log_ERROR,'SPI_Dev_Init: can''t get SPI mode '+LNX_ErrDesc(fpgeterrno));   
		    res:=fpioctl(spi_fd,SPI_IOC_RD_MAX_SPEED_HZ,@spi_speed);
//writeln('SPI-MaxSpeed: ',spi_speed);
		    if (res=-1) then Log_Writeln(Log_ERROR,'SPI_Dev_Init: can''t get max speed '+LNX_ErrDesc(fpgeterrno));	
		    res:=fpioctl(spi_fd,SPI_IOC_RD_BITS_PER_WORD,@spi_bpw);
		    if (res=-1) then Log_Writeln(Log_ERROR,'SPI_Dev_Init: can''t get bits per word '+LNX_ErrDesc(fpgeterrno));
		  {$RANGECHECKS ON}    
	    {$ENDIF}
      end;
	  if (spi_fd<0) then 
	  begin
	    Log_Writeln(LOG_WARNING,'SPI_Dev_Init[0x'+Hex(busnum,2)+'/'+Hex(devnum,2)+']: '+spi_path);
	    if LOG_Level<=LOG_DEBUG then SPI_show_dev_info_struct(busnum,devnum);
	  end
	  else ok:=true;
    end; // with
  end else LOG_Writeln(LOG_ERROR,'SPI_Dev_Init[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
//SPI_show_dev_info_struct(spi_dev[devnum], devnum);
  SPI_Dev_Init:=ok;
end;

function  SPI_Dev_Init(busnum,devnum:byte):boolean;
begin SPI_Dev_Init:=SPI_Dev_Init(busnum,devnum,8,0,SPI_MODE_0,spi_bus[busnum].spi_maxspeed,0); end;

procedure SPI_Start(busnum:byte);
var devnum:byte;
begin
  Log_Writeln(LOG_DEBUG,'SPI_Start busnum: '+Num2Str(busnum,0));
  if (busnum<=spi_max_bus) then
  begin
    with spi_bus[busnum] do 
    begin 
	  spi_maxspeed:=SPI_GetSpeed(busnum);
	  SPI_useCS:=false;
	  InitCriticalSection(SPI_CS);
      for devnum:=0 to spi_max_dev do SPI_Dev_Init(busnum,devnum);
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_Start[0x'+Hex(busnum,2)+']: invalid busnum');
end;

procedure SPI_Start;  
var i:integer; 
begin 
  for i:=0 to spi_max_bus do SPI_Start(i);  
end;

procedure SPI_Bus_Close(busnum:byte);
var devnum:byte;
begin
  if (busnum<=spi_max_bus) then
  begin
    for devnum:=0 to spi_max_dev do
    begin	
      with spi_dev[busnum,devnum] do 
      begin 
        {$IFDEF UNIX} 
          if (spi_fd>=0) then 
          begin
            DoneCriticalSection(SPI_bus[busnum].SPI_CS);
            fpclose(spi_fd); 
          end;
        {$ENDIF}
        spi_fd:=-1; 
      end;
	end; // for
  end else LOG_Writeln(LOG_ERROR,'SPI_Bus_Close[0x'+Hex(busnum,2)+']: invalid busnum');
end;

procedure SPI_Bus_Close_All; 
var i:integer; 
begin 
  for i:=0 to spi_max_bus do SPI_Bus_Close(i); 
end;

procedure SPI_Loop_Test;
const busnum=0; devnum=0; 		// test on /dev/spidev0.0 // spidev<busnum.devnum>
	  requestedspeed=1000000;	// MaxBusSpeed ~7.8MHz
	  seq=	'HELLO';
//	seq=	'HELLO - this is a SPI-Loop-Test'; // 31 Bytes
var rslt,cnt:integer; tv_start,tv_end:timespec; us:int64; 
begin
  writeln('SPI_Loop_Test+: Start');
  writeln('  pls. connect/short MOSI and MISO line (GPIO10/GPIO9).');
  writeln('  If you remove the wire between MOSI and MISO, and connect the MISO');
  writeln('  "H"-Level (+3.3 V), you should be able to read 0xFFs.');
  writeln('  If you connect MISO to ground (GND), you should receive 0x00s for each byte instead.');
  writeln('  we will send 8x byte sequence 0x'+HexStr(seq));
  writeln('  with a length of '+Num2Str(Length(seq),0)+' bytes and should also receive it. <CR>');
  readln;
  cnt:=0;
  SPI_Dev_Init(busnum,devnum,8,0,SPI_MODE_0,requestedspeed,10);	
  repeat
    clock_gettime(CLOCK_REALTIME,@tv_start);
    rslt:=SPI_Transfer(busnum,devnum,	seq(*+seq+seq+seq+seq+seq+seq+seq*));
    clock_gettime(CLOCK_REALTIME,@tv_end);
    if rslt>=0 then
    begin
      us:=MicroSecondsBetween(tv_end,tv_start);
      writeln('SPI_Loop_Test: success, NumBytes:',rslt:0,' within ',us:0,'us (',(rslt/us*1000):0:1,'kB/s MaxBusSpeed:',(SPI_GetFreq(requestedspeed)/1000):0:1,'kHz)');
      SPI_Show_Buffer(busnum,devnum); 
      writeln('responsestr: 0x',HexStr(spi_buf[busnum,devnum].buf));
    end else LOG_Writeln(LOG_ERROR,'SPI_Loop_Test: errnum: '+Num2Str(rslt,0));
	delay_msec(1000); 
	inc(cnt);
  until (cnt>=1);
  writeln('SPI_Loop_Test-: End');
end;

procedure rfm22B_ShowChipType;
(* just to test SPI Read Function. Installed RFM22B Module on piggy back board is required!! *)
const RF22_REG_01_VERSION_CODE = $01; busnum=0; devnum=0;
  function  GDVC(b:byte):string;
  var t:string;
  begin
    case (b and $1f) of
      $01 : t:='SIxxx_X4';
      $02 : t:='SI4432_V2';
      $03 : t:='SIxxx_A0';
	  $04 : t:='SI4431_A0';
	  $05 : t:='SI443x_B0';
      $06 : t:='SI443x_B1';
      else  t:='RFM_UNKNOWN';
    end;
    GDVC:='0x'+Hex(b,2)+' '+t;
  end;
begin
  writeln('Chip-Type: '+
    GDVC(SPI_Read(busnum,devnum,RF22_REG_01_VERSION_CODE))+
	' (correct answer should be 0x06)');  
end;
procedure SPI_Test; begin rfm22B_ShowChipType; end;

function RPI_OSrev:string;  		begin RPI_OSrev:=os_rev;  end;
function RPI_uname:string;  		begin RPI_uname:=uname;   end;
function RPI_hw  :string;  			begin RPI_hw  :=cpu_hw;   end;
function RPI_fw  :string;  			begin RPI_fw  :=cpu_fw;   end;
function RPI_proc:string;  			begin RPI_proc:=cpu_proc; end;
function RPI_mips:string;  			begin RPI_mips:=cpu_mips; end;
function RPI_feat:string;  			begin RPI_feat:=cpu_feat; end;
function RPI_rev :string;  			begin RPI_rev :=cpu_rev; end;
function RPI_machine:string;  		begin RPI_machine:=cpu_machine; end;
function RPI_cores:longint;  		begin RPI_cores:=cpu_cores; end;
function RPI_revnum:real;  			begin RPI_revnum:=cpu_rev_num; end;
function RPI_gpiomapidx:byte;  		begin RPI_gpiomapidx:=GPIO_map_idx; end;
function RPI_hdrpincount:byte;  	begin RPI_hdrpincount:=connector_pin_count; end; 
function RPI_freq :string; 			begin RPI_freq :=cpu_fmin+';'+cpu_fcur+';'+cpu_fmax+';Hz'; end;
function RPI_status_led_GPIO:byte;	begin RPI_status_led_GPIO:=status_led_GPIO; end;
function RPI_snr :string;  			begin RPI_snr :=cpu_snr;  end;

function  RPI_I2C_BRadj(i2c_speed_kHz:longint):longint;	
// https://periph.io/platform/raspberrypi/ 
// http://forum.weihenstephan.org/forum/phpBB3/viewtopic.php?t=684
var br:longint; //vs:string;
begin // RPI_rev e.g: rev4;1024MB;3B;BCM2835;a02082;40
//  vs:=Upper(Select_Item(RPI_rev,';','',3));	// e.g. 3B
  br:=i2c_speed_kHz;
//  if (Pos('3B',vs)<>0)	then br:=round(i2c_speed_kHz*1.6);	// RPI3
//	if (Pos('2B',vs)<>0)	then br:=round(i2c_speed_kHz*2.0);	// RPI2
  RPI_I2C_BRadj:=br;
end;

function RPI_I2C_busnum(func:byte):byte; 
//get the I2C busnumber, where e.g. the general purpose devices are connected. 
//This depends on rev1 or rev2 board . e.g. RPI_I2C_busnum(RPI_I2C_general_purpose_bus_c) }
var b:byte;
begin
  b:=I2C_busnum; if func<>RPI_I2C_general_purpose_bus_c then inc(b);
  RPI_I2C_busnum:=(b mod 2);
end;

function RPI_I2C_busgen:byte; begin RPI_I2C_busgen:=RPI_I2C_busnum(RPI_I2C_general_purpose_bus_c);   end;
function RPI_I2C_bus2nd:byte; begin RPI_I2C_bus2nd:=RPI_I2C_busnum(RPI_I2C_general_purpose_bus_c+1); end;

procedure RPI_show_cpu_info;
begin
  writeln('rpi Snr  : ',RPI_snr);
  writeln('rpi HW   : ',RPI_hw);
  writeln('rpi proc : ',RPI_proc);
  writeln('rpi rev  : ',RPI_rev);
  writeln('rpi mips : ',RPI_mips);
  writeln('rpi Freq : ',RPI_freq);
  writeln('rpi Osci : ',(CLK_GetFreq(1)/1000000):7:2,' MHz');
  writeln('rpi PLLC : ',(CLK_GetFreq(5)/1000000):7:2,' MHz (CoreFreq)');
  writeln('rpi PLLD : ',(CLK_GetFreq(6)/1000000):7:2,' MHz');
  writeln('rpi HDMI : ',(CLK_GetFreq(7)/1000000):7:2,' MHz'); 
  writeln('CLK min  : ',(CLK_GetMinFreq/1000):   7:2,' kHz');
  writeln('CLK max  : ',(CLK_GetMaxFreq/1000000):7:2,' MHz');
  writeln('PWMHW min: ',(PWM_GetMinFreq(PWM_DIVImax)/1.0):7:2,' Hz');
  writeln('PWMHW max: ',(PWM_GetMaxFreq(PWM_DIVImin)/1000):7:2,' kHz'); 
end;

procedure RPI_show_SBC_info; begin RPI_show_cpu_info; end;

procedure RPI_show_all_info;
begin
  RPI_show_SBC_info;	writeln;
  GPIO_show_regs;		writeln;
  if (not restrict2gpio) then
  begin
    spi0_show_regs;		writeln;
    pwm_show_regs;		writeln;
    clk_show_regs;		writeln;
    stim_show_regs;		writeln;
    tim_show_regs;		writeln;
    q4_show_regs; 		writeln; 
    i2c0_show_regs;		writeln;
    i2c1_show_regs;		writeln;
//  i2c2_show_regs;		writeln;
    Clock_show_regs; writeln;
    GPIO_ShowConnector;
  end else Log_Writeln(Log_WARNING,'RPI_show_all_info: can report GPIO register only');
end;

procedure GPIO_create_int_script(filn:string);
const logfil_c='/tmp/GPIO_script.log';
var fil:text; sh:string;
begin
  {$I-} 
    assign (fil,filn); rewrite(fil);
    writeln(fil,'#!/bin/bash');
	writeln(fil,'# script was automatically created. Do not edit');
	writeln(fil,'# usage e.g.:');
	writeln(fil,'# usage e.g.: '+filn+' 22 in rising');
	writeln(fil,'# usage e.g.: '+filn+' 22 stop');
	writeln(fil,'#');
	writeln(fil,'logf='+logfil_c);
	writeln(fil,'path='+GPIO_path_c);
	writeln(fil,'gpionum=$1');
	writeln(fil,'direction=$2');
    writeln(fil,'edgetype=$3');
	writeln(fil,'if ([ "$gpionum" ==   ""       ] || [ "$direction" == ""        ]) ||');
    writeln(fil,'   ([ "$direction" != "in"     ] && [ "$direction" != "out"     ]  && [ "$direction" != "stop" ]) || ');
	writeln(fil,'   ([ "$edgetype"  != "rising" ] && [ "$edgetype"  != "falling" ]  && [ "$direction" != "stop" ]) ; then');
    writeln(fil,'  echo "no valid parameter $1 $2 $3"');
    writeln(fil,'  echo "$0 <gpionum> <[in|out|stop]> <[rising|falling]>"');
    writeln(fil,'  exit 1;');
    writeln(fil,'fi');
	writeln(fil,'#');
	writeln(fil,'echo $0 $1 $2 $3 $4 $5 $6 $7 $8 $9 > $logf');
	writeln(fil,'echo   $gpionum   > $path/unexport');
	writeln(fil,'if ([ "$direction" == "in" ] || [ "$direction" == "out" ]); then');
	writeln(fil,'  echo create gpio$gpionum $direction $edgetype >> $logf');
    writeln(fil,'  echo $gpionum   > $path/export');
    writeln(fil,'  echo $direction > $path/gpio$gpionum/direction');
    writeln(fil,'  echo $edgetype  > $path/gpio$gpionum/edge');
	writeln(fil,'#');
	writeln(fil,'  echo  $path/gpio$gpionum/ >> $logf');
	writeln(fil,'  ls -l $path/gpio$gpionum/ >> $logf');
    writeln(fil,'fi');
	writeln(fil,'#');
    writeln(fil,'exit 0');
    close(fil);
  {$I+} 
  call_external_prog(LOG_NONE,'chmod +x '+filn,sh);   
end;

{$IFDEF UNIX}
function RPI_hal_Dummy_INT(GPIO_nr:integer):integer;
// if isr routine is not initialized
begin
  writeln ('RPI_hal_Dummy_INT fired for GPIO',GPIO_nr);
  RPI_hal_Dummy_INT:=-1;
end;

function my_isr(GPIO_nr:integer):integer;
// for GPIO_int testing. will be called on interrupt
const waittim_ms=1;
begin
  writeln ('my_isr fired for GPIO',GPIO_nr,' servicetime: ',waittim_ms:0,'ms');
  sleep(waittim_ms);
  my_isr:=999;
end;

//* Bits from:
//https://www.ridgerun.com/developer/wiki/index.php/Gpio-int-test.c */
//static void *
// https://github.com/omerk/pihwm/blob/master/lib/pi_gpio.c
// https://github.com/omerk/pihwm/blob/master/demo/GPIO_int.c
// https://github.com/omerk/pihwm/blob/master/lib/pihwm.c
function isr_handler(p:pointer):longint; // (void *isr)
const testrun_c=true;
    STDIN_FILENO = 0; STDOUT_FILENO = 1; STDERR_FILENO = 2; 
	POLLIN = $0001; POLLPRI = $0002; 
var rslt:integer; nfds,rc:longint; 
    buf:array[0..63] of byte; fdset:array[0..1] of pollfd; 
	testrun:boolean; isr_ptr:^isr_t; Call_Func:TFunctionOneArgCall;
begin
  rslt:=0; nfds:=2; testrun:=testrun_c; isr_ptr:=p; Call_Func:=isr_ptr^.func_ptr;
  if testrun then writeln('## ',isr_ptr^.gpio);
  if (isr_ptr^.flag=1) and (isr_ptr^.fd>=0) then
  begin
    if testrun then writeln('isr_handler running for GPIO',isr_ptr^.gpio);
    while true do
	begin
      fdset[0].fd := STDIN_FILENO; fdset[0].events := POLLIN;  fdset[0].revents:=0;
      fdset[1].fd := isr_ptr^.fd;  fdset[1].events := POLLPRI; fdset[1].revents:=0;

      rc := FPpoll (fdset, nfds, 1000);	// Timeout in ms 

      if (rc < 0) then begin if testrun then writeln('poll() failed!'); rslt:=-1; exit(rslt); end;
	  
      if (rc = 0) then
	  begin
	    if testrun then writeln('poll() timeout.');
        if (isr_ptr^.flag = 0) then
        begin
          if testrun then writeln('exiting isr_handler (timeout)');
		  EndThread;
        end;
      end; 

      if ((fdset[1].revents and POLLPRI)>0) then
	  begin //* We have an interrupt! */
        if (fpread(fdset[1].fd,buf,SizeOf(buf))=-1) then
		begin
          if testrun then writeln('read failed for interrupt');
		  rslt:=-1;
		  exit(rslt);
        end;
		InterLockedIncrement(isr_ptr^.int_cnt_raw);
        if isr_ptr^.int_enable then 
		begin 
		  InterLockedIncrement(isr_ptr^.int_cnt); 
		  InterLockedIncrement(isr_ptr^.enter_isr_routine);
		  isr_ptr^.enter_isr_time:=now;
		  isr_ptr^.rslt:=Call_Func(isr_ptr^.gpio); 
		  isr_ptr^.last_isr_servicetime:=MilliSecondsBetween(now,isr_ptr^.enter_isr_time);
		  InterLockedDecrement(isr_ptr^.enter_isr_routine);
		end;
      end;

      if ((fdset[0].revents and POLLIN)>0) then
	  begin
        if (fpread(fdset[0].fd,buf,1)=-1) then
        begin
          if testrun then writeln('read failed for stdin read');
          rslt:=-1;
		  exit(rslt);
        end;
        if testrun then writeln('poll() stdin read 0x',Hex(buf[0],2));
      end;  
      flush (stdout);
    end;
  end
  else
  begin
    if testrun then writeln('exiting isr_handler (flag)');
    EndThread;
  end;
  isr_handler:=rslt;
end;

function  WriteStr2UnixDev(dev,s:string):integer; 
var rslt:integer; lgt:byte; buffer:I2C_databuf_t; 
begin  
  rslt:=-1;
  {$IFDEF UNIX}
    with buffer do
    begin
	  lgt:=length(s);
	  {$warnings off}
      if lgt>SizeOf(buf) then 
	  begin
	    LOG_Writeln(LOG_ERROR,'WriteStr2UnixDev: string to long: '+Num2Str(lgt,0)+'/'+Num2Str(SizeOf(buf),0));
	    exit(-1);
      end;		
      {$warnings on}
      buf:=s;
      hdl:=fpopen(dev, Open_RDWR or O_NONBLOCK);
      if hdl<0 then exit(-2); 
	  rslt:=fpWrite(hdl,buf,lgt);
	  if (rslt<0)	then LOG_Writeln(LOG_ERROR,'WriteStr2UnixDev: '+LNX_ErrDesc(fpgeterrno));
      if (rslt=lgt) then rslt:=0;
	  fpclose(hdl);
    end; // with
  {$ENDIF}
  WriteStr2UnixDev:=rslt;
end;
 
function GPIO_OpenFile(var isr:isr_t):integer;
// needed, because this is the only known possibility to use ints without kernel modifications.
(* path=/sys/class/gpio
   echo $gpionum	> $path/export
   echo in 			> $path/gpio$gpionum/direction
   echo $edgetype	> $path/gpio$gpionum/edge
*)
var rslt:integer; pathstr,edge_type:string; 
begin
  rslt:=0; pathstr:=GPIO_path_c+'/gpio'+Num2Str(isr.gpio,0); 
  if isr.rising_edge then edge_type:='rising' else edge_type:='falling';
  writeln('GPIO_OpenFile');
  {$I-}
    if (WriteStr2UnixDev(GPIO_path_c+'/export',Num2Str(isr.gpio,0))=0) then
      if (WriteStr2UnixDev(pathstr+'/direction','in')=0) then
	      WriteStr2UnixDev(pathstr+'/edge',edge_type);
    if FileExists(pathstr+'/value') then 
	  isr.fd:=fpopen(pathstr+'/value', O_RDONLY or O_NONBLOCK );
  {$I+} 
  if (isr.fd<0) then rslt:=-1;
  GPIO_OpenFile:=rslt;
end;

function GPIO_int_active(var isr:isr_t):boolean;
begin
  if isr.fd>=0 then GPIO_int_active:=true else GPIO_int_active:=false;
end;

function GPIO_set_int(var isr:isr_t; GPIO_num:longint; isr_proc:TFunctionOneArgCall; flags:s_port_flags) : integer;
var rslt:integer; _flags:s_port_flags; GPIO_struct:GPIO_struct_t;
begin
  rslt:=-1; _flags:=flags;
//writeln('GPIO_int_set ',GPIO_num);
  isr.gpio:=GPIO_num;  			isr.flag:=1; 	isr.rslt:=0; 		isr.int_enable:=false; 
  isr.fd:=-1;          			isr.int_cnt:=0;	isr.int_cnt_raw:=0;	isr.enter_isr_routine:=0;		
  isr.last_isr_servicetime:=0; 	isr.enter_isr_time:=now; 
  isr.func_ptr:=@RPI_hal_Dummy_INT;  
  _flags:=_flags+[INPUT]-[OUTPUT,PWMHW,PWMSW]; // interrupt is INPUT, remove all Output flags
  isr.rising_edge:=true; // default
  if (FallingEdge IN _flags) then isr.rising_edge:=false; 	
  if (RisingEdge  IN _flags) then isr.rising_edge:=true; 	
  if isr.rising_edge 
    then _flags:=_flags+[RisingEdge]
	else _flags:=_flags+[FallingEdge]; 
  GPIO_SetStruct(GPIO_struct,1,isr.gpio,'INT',_flags);  
  if (isr.gpio>=0) and GPIO_Setup(GPIO_struct) then
  begin 
    if GPIO_OpenFile(isr)=0 then 
    begin
	  if (isr_proc<>nil) then isr.func_ptr:=isr_proc;
      BeginThread(@isr_handler,@isr,isr.ThreadId);  // http://www.freepascal.org/docs-html/prog/progse43.html
      isr.ThreadPrio:=ThreadGetPriority(isr.ThreadId);  
	  rslt:=0;
    end
	else LOG_Writeln(LOG_ERROR,'GPIO_SETINT: Could not set INT for GPIO'+Num2Str(GPIO_num,0));
  end;
  if rslt<>0 then LOG_Writeln(LOG_ERROR,'GPIO_SETINT: err:'+Num2Str(rslt,0));
  GPIO_set_int:=rslt;
end;

function GPIO_int_release(var isr:isr_t):integer;
var rslt:integer;
begin
  rslt:=0;
//writeln('GPIO_int_release: pin: ',isr.gpio);
  isr.flag:=0; isr.int_enable:=false; delay_msec(100); // let Thread Time to terminate
  GPIO_set_edge_rising (isr.gpio,false);
  GPIO_set_edge_falling(isr.gpio,false); 
  if isr.fd>=0 then 
  begin 
    fpclose(isr.fd); isr.fd:=-1; 
	WriteStr2UnixDev(GPIO_path_c+'/unexport',Num2Str(isr.gpio,0));
  end;
  GPIO_int_release:=rslt;
end;

procedure instinthandler;  // not ready ,  inspiration http://lnxpps.de/rpie/
//var rslt:integer; p:pointer;
begin
//  writeln(request_irq(110,p,SA_INTERRUPT,'short',nil));
end;

procedure GPIO_int_enable (var isr:isr_t); begin isr.int_enable:=true;  (*writeln('int Enable  ',isr.gpio);*) end;
procedure GPIO_int_disable(var isr:isr_t); begin isr.int_enable:=false; writeln('int Disable ',isr.gpio); end;

procedure inttest(GPIO_nr:longint);
// shows how to use the GPIO_int functions
const loop_max=30;
var cnt:longint; isr:isr_t; 
begin
  writeln('INT main start on GPIO',GPIO_nr,' loops: ',loop_max:0);
  GPIO_set_int   (isr,GPIO_nr,@my_isr,[RisingEdge]); // set up isr routine, initialize isr struct: GPIO_number, int_routine which have to be executed, rising_edge
  GPIO_int_enable(isr); // Enable Interrupts, allows execution of isr routine
  for cnt:=1 to loop_max do
  begin
    write  ('doing nothing, waiting for an interrupt on GPIO',GPIO_nr:0,' loopcnt: ',cnt:3,' int_cnt: ',isr.int_cnt:3,' ThreadID: ',longword(isr.ThreadID),' ThPrio: ',isr.ThreadPrio);
	if isr.rslt<>0 then begin write(' result: ',isr.rslt,' last service time: ',isr.last_isr_servicetime:0,'ms'); isr.rslt:=0; end;
	writeln;
    sleep (1000);
  end; 
  GPIO_int_disable(isr);
  GPIO_int_release(isr);
  writeln('INT main end   on GPIO',GPIO_nr);
end;

procedure GPIO_int_test; // shows how to use the GPIO_int functions
const gpio=22; 
begin
  writeln('GPIO_int_test: GPIO',gpio,' HWPin:',GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio));
  inttest(gpio);
end;

{$ENDIF}

procedure BB_OOK_PIN(state:boolean);
// this procedure, uses a gpio pin for OOK (OnOffKeying). 
begin
//Writeln('BB_OOK_PIN(state: '+Bool2Str(state)+' Pin: '+Num2Str(BB_pin,0));
  Log_Writeln(LOG_DEBUG,'BB_OOK_PIN(state: '+Bool2Str(state)+' Pin: '+Num2Str(BB_pin,0));
  if BB_pin>0	then GPIO_set_PIN(BB_pin,state) 
				else LOG_WRITELN(LOG_ERROR,'BB_OOK_PIN: unknown GPIO number '+Num2Str(BB_pin,0));
end;

procedure BB_BitBang(codestring,Pat:string; periodusec_short,periodusec_long,periodusec_sync,repl:longint); // Pat: '0,HpLPHpLP;1,HPLpHPLp;X,HpLPHPLp;S,HpLS'
  procedure play(str:string);
  var i:integer;
  begin
    for i := 1 to length(str) do
	begin
	  case str[i] of
	    'L','l' : BB_OOK_PIN(false);
		'H','h' : BB_OOK_PIN(true);
		'p'		: delay_us(periodusec_short);	
		'P'		: delay_us(periodusec_long);	
		'S'		: delay_us(periodusec_sync);	
		' ' 	: begin { do nothing, just for formatting reasons } end; 
		else	  LOG_WRITELN(LOG_ERROR,'BB_BitBang: wrong pattern: '+str[i]+' playstr '+str);
	  end;
	end;
  end;
var   i,j:integer; H,L,X,S,sh1,sh2:string;
begin
  H:=''; L:=''; X:=''; S:=''; 
  for i := 1 to Anz_Item(Pat,';','') do
  begin
    sh1:=Select_Item(Pat,';','',i); sh2:=Select_Item(sh1,',','',2); sh1:=Select_Item(sh1,',','',1);
	if sh1='0' then L:=sh2; if sh1='1' then H:=sh2; if sh1='X' then X:=sh2; if sh1='S' then S:=sh2;
  end;
  for i := 1 to repl do
  begin
    for j := 1 to Length(codestring) do
    begin
      case codestring[j] of
        '0' : play(L);
		'1' : play(H);
		'X' : play(X);
		'S' : play(S);
		' ' : begin { do nothing, just for formatting reasons } end; 
		else  LOG_WRITELN(LOG_ERROR,'BB_BitBang: wrong pattern: '+codestring[j]+' in '+codestring);
	  end;
    end;
  end;
end; { BB_BitBang }

procedure BB_SendCode(switch_type:T_PowerSwitch; adr,id,desc:string; ein:boolean);
{ https://github.com/tandersson/rf-bitbanger/blob/master/rfbb_cmd/rfbb_cmd.c }
var   s,pat:string; ok:boolean; periodusec_short,periodusec_long,periodusec_sync,repl:longint;
begin
  s:=FilterChar(adr,'01'); pat:=''; ok:=false; repl:=10; periodusec_short:=340; periodusec_long:=3*periodusec_short; periodusec_sync:=32*periodusec_short;
  LOG_Writeln(LOG_DEBUG,'BB_SendCode on:'+Bool2Str(ein)+' TYP:'+GetEnumName(TypeInfo(T_PowerSwitch),ord(switch_type))+' ADR:'+adr+' DESC:'+desc);
//Writeln              ('BB_SendCode on:'+Bool2Str(ein)+' TYP:'+GetEnumName(TypeInfo(T_PowerSwitch),ord(switch_type))+' ADR:'+adr+' DESC:'+desc);  
  if s<>'' then
  begin
    LED_Status(false); 
	BB_OOK_PIN(false);	
    case switch_type of
	  ELRO,Sartano:	begin // This is tested, I have an ELRO PowerSwitch
					  ok:=true; pat:='0,HpLPHPLp;1,HpLPHpLP;S,HpLS';
					  repl:=15; periodusec_short:=320; periodusec_long:=3*periodusec_short; periodusec_sync:=31*periodusec_short; 
					  if ein then s:=s+'10' else s:=s+'01'; s:=s+'S'; // ein: '00' ???
					end;
	  nexa: 		begin {	This is not tested, I don't have a nexa PowerSwitch
							http://elektronikforumet.syntaxis.se/wiki/index.php/RF_Protokoll_-_Nexa/Proove_%28%C3%A4ldre,_ej_sj%C3%A4lvl%C3%A4rande%29
							The bit coding used by the encoder chips, for example M3E. from MOSDESIGN SEMICONDUCTOR, allows for trinary codes, ie '0','1' and 'X' (OPEN/FLOATING). 
							However, it seems that only '0' and 'X' is currently used in the NEXA/PROOVE remotes. 
							The high level in the ASCII-graphs below denotes the transmission of the 433 MHz carrier. The low level means no carrier.}
					  ok:=true; pat:='0,HpLPHpLP;1,HPLpHPLp;X,HpLPHPLp;S,HpLS';	
					  repl:=10; periodusec_short:=340; periodusec_long:=3*periodusec_short; periodusec_sync:=32*periodusec_short;
					  if ein then s:=s+'10' else s:=s+'01'; s:=s+'S'; 
					  s:=StringReplace(s,'1','X',[rfReplaceAll,rfIgnoreCase]);
					end;
	  Intertechno:	begin { This is not tested, I don't have a Intertechno PowerSwitch
							CONRAD-Intertechno: http://blog.sui.li/2011/04/12/low-cost-funksteckdosen-arduino/ }
					  ok:=true; pat:='0,HpLPHpLP;1,HPLpHpLP;S,HpLS'; 	
					  repl:=10; periodusec_short:=320; periodusec_long:=3*periodusec_short; periodusec_sync:=32*periodusec_short;
					  if ein then s:=s+'1'  else s:=s+'0';  s:=s+'S'; 
					end;
	  else          LOG_Writeln(LOG_ERROR,'BB_SendCode: unknown switchtype: '+GetEnumName(TypeInfo(T_PowerSwitch),ord(switch_type)));
    end;
	if ok then BB_BitBang(s, Pat, periodusec_short, periodusec_long, periodusec_sync, repl); 
	BB_OOK_PIN(false); 	
    LED_Status(true);
	sleep(1);	
  end;
end;

procedure BB_SetPin(gpio:longint); 
begin 
  BB_pin:=gpio; 
  Log_Writeln(LOG_DEBUG,'BB_SetPin: '+Num2Str(BB_pin,0)); 
  if (BB_pin>0) then GPIO_set_OUTPUT(BB_pin); 
//writeln('BB_SetPin: ',BB_pin);
end;

function  BB_GetPin:longint; begin BB_GetPin:=BB_pin; end;

procedure BB_InitPin(id:string); // e.g. id:'TLP434A' or id:'13'  (direct RPI Pin on HW Header P1 )
var devnum:byte; BBPin:longint; sh:string; 
begin
  sh:=Upper(id);
  if not Str2Num(Select_Item(sh,',','',1),BBpin) then BBpin:=-1;
  devnum:=0;
  if (sh='TLP434A') 	then devnum:=1;
  if (sh='TX433N') 		then devnum:=1;
  if (sh='TWS-BS') 		then devnum:=1; // from Sparkfun WRL-10534 
  if (sh='RFM22B')	 	then devnum:=2;
  case devnum of
	 1 : 					BBpin:=GPIO_MAP_HDR_PIN_2_GPIO_NUM(IO1_Pin_on_RPI_Header,	RPI_gpiomapidx);  
	 2 : 					BBpin:=GPIO_MAP_HDR_PIN_2_GPIO_NUM(OOK_Pin_on_RPI_Header,	RPI_gpiomapidx); 
	else if BBpin>0 then	BBpin:=GPIO_MAP_HDR_PIN_2_GPIO_NUM(BBpin, 					RPI_gpiomapidx); 
  end;
  BB_SetPin(BBpin);
end;

procedure ELRO_TEST;
// Set your ELRO PowerSwitch to the following System- and Unit_A-Code
const id_c='ELRO-A'; SystemCode_c='10001'; Unit_A_c='10000'; Unit_B_c='01000'; Unit_C_c='00100'; Unit_D_c='00010'; Unit_E_c='00001'; 
var cnt:integer; oldpin:longint;
begin
  oldpin:=BB_GetPin;															// save it
  BB_SetPin(GPIO_MAP_HDR_PIN_2_GPIO_NUM(IO1_Pin_on_RPI_Header,RPI_gpiomapidx)); // set the pin to OOK Pin for the piggyback-board Transmitter Chip (433.92 Mhz)
  writeln('Start  ELRO_TEST');
  for cnt := 1 to 15 do
  begin
    writeln(cnt:2,'. EIN: '+id_c); LED_Status(true); BB_SendCode(ELRO,SystemCode_c+Unit_A_c,id_c,'ELRO Switch A, System-Code: ON  OFF OFF OFF ON   Unit-Code: ON  OFF OFF OFF OFF', true);  sleep(1500); LED_Status(false); 
	writeln(cnt:2,'. AUS: '+id_c); LED_Status(true); BB_SendCode(ELRO,SystemCode_c+Unit_A_c,id_c,'ELRO Switch A, System-Code: ON  OFF OFF OFF ON   Unit-Code: ON  OFF OFF OFF OFF', false); sleep(2000); LED_Status(false); 
	writeln; writeln;
  end;
  writeln('End   ELRO_TEST');
  BB_SetPin(oldpin);															// restore it
end;

procedure MORSE_speed(speed:integer); // 1..5, -1=default_speed
//WpM:WordsPerMinute; BpM:Buchstaben/Letter pro Minute
begin
  MORSE_dit_lgt			:= 120;	//  10WpM=50BpM	-> 120ms // default
  case speed of
      1 : MORSE_dit_lgt	:=1200;	//  1WpM=  5BpM	->1200ms 
	  2 : MORSE_dit_lgt	:= 240;	//  5WpM= 25BpM	-> 240ms
	  3 : MORSE_dit_lgt	:= 150;	//  8WpM		-> 150ms 
	  4 : MORSE_dit_lgt	:= 120;	// 10WpM= 50BpM	-> 120ms
	  5 : MORSE_dit_lgt	:=  60;	// 20WpM=100BpM	->  60ms
  end;
end;

procedure MORSE_tx(s:string);
// http://de.wikipedia.org/wiki/Morsezeichen
// http://en.wikipedia.org/wiki/MORSE_code
const test=true; CH_c = 'c'; 
  MORSE_char : array [01..26,01..02] of string = 
  ( ('.-',  'A') , ('-...','B') , ('-.-.','C') , ('-..', 'D') , ('.',   'E') , 
    ('..-.','F') , ('--.', 'G') , ('....','H') , ('..',  'I') , ('.---','J') ,
    ('-.-', 'K') , ('.-..','L') , ('--',  'M') , ('-.',  'N') , ('---', 'O') ,
    ('.--.','P') , ('--.-','Q') , ('.-.', 'R') , ('...', 'S') , ('-',   'T') ,
    ('..-', 'U') , ('...-','V') , ('.--', 'W') , ('-..-','X') , ('-.--','Y') ,
    ('--..','Z') );
 
  MORSE_digit : array [01..10,01..02] of string = 
  ( ('-----','0') , ('.----','1') , ('..---','2') , ('...--', '3') , ('....-','4') ,
    ('.....','5') , ('-....','6') , ('--...','7') , ('---..', '8') , ('----.','9') );

  sc1_count = 27;
  MORSE_sc1 : array [01..sc1_count,01..02] of string = 
  ( ('----',  CH_c),
    ('.-.-.-','.') , ('--..--',',') ,  ('---...', ':') , ('-.-.-.',';') , ('..--..','?') ,   
    ('-.-.--','!') , ('-....-','-') ,  ('..--.-', '_') , ('-.--.', '(') , ('-.--.-',')') , 
	('.----.',''''), ('-...-', '=') ,  ('.-.-.',  '+') , ('-..-.', '/') , ('.--.-.','@') ,
	('.-...', '&') , ('.-..-.','"') ,  ('...-..-','$') ,
    ('.-.-',  'Ä') , ('---.',  'Ö') ,  ('..--',   'Ü') , ('...--..','ß'), ('.--.-', 'À') ,
	('.--.-', 'Å') , ('.-..-', 'È') ,  ('--.--',  'Ñ') 
  );

var sh,sh2:string; n : longint; dit_lgt,dah_lgt,symbol_end,letter_end,word_end:word;

  procedure MORSE_wait(w:word); begin delay_msec(w) end;
  procedure dit; begin BB_OOK_PIN(AN); MORSE_wait(dit_lgt); BB_OOK_PIN(AUS); end; 
  procedure dah; begin BB_OOK_PIN(AN); MORSE_wait(dah_lgt); BB_OOK_PIN(AUS); end; 
  procedure sig (ch:char); begin if test then write(ch); if ch='.' then dit else dah; end;
  
  function  sc1 (s:string):string; var sh:string; j:longint; begin sh:=''; for j := 1 to sc1_count do if s=MORSE_sc1[j,2] then sh:=MORSE_sc1[j,1]; sc1:=sh; end;
  procedure mors(s1,s2:string);    var n : longint; begin if test then begin if s1=CH_c then write('CH') else write(s1); write(' '); end; for n := 1 to Length(s2) do begin sig(s2[n]); if n<Length(s2) then MORSE_wait(symbol_end); end; if test then writeln; end;
  
begin
  dit_lgt:=MORSE_dit_lgt; dah_lgt:=3*dit_lgt; symbol_end:=dit_lgt; letter_end:=dah_lgt; word_end:=7*dit_lgt; // define timing, depending on external variable MORSE_dit_lgt set by procedure MORSE_speed
  LOG_Writeln(LOG_DEBUG,'Morse: '+s);
  if test then  writeln('Morse: '+s);
  sh:=Upper(s);
//sh:=StringReplace(sh,'CH',CH_c,[rfReplaceAll]); // replace 'CH' with one character
  for n := 1 to Length(sh) do
  begin
    case sh[n] of
	  ' '	   : begin MORSE_wait(word_end); if test then writeln; end;
      'A'..'Z' : begin sh2:=MORSE_char [ord(sh[n])-ord('A')+1,1]; mors(sh[n],sh2); MORSE_wait(letter_end); end;
	  '0'..'9' : begin sh2:=MORSE_digit[ord(sh[n])-ord('0')+1,1]; mors(sh[n],sh2); MORSE_wait(letter_end); end;
	  else       begin sh2:=sc1(sh[n]);                           mors(sh[n],sh2); MORSE_wait(letter_end); end;
	end;
  end;
  if test then writeln;
end;

procedure MORSE_test;
var oldpin:longint;
begin
  oldpin:=BB_GetPin;						// save it
  BB_SetPin(RPI_status_led_GPIO); 			// set the pin to Rpi Status LED
  MORSE_speed(3);							// 3: 8WpM	-> 150ms 
  MORSE_tx('Hello this is a Morse Test.');	// The Status LED should blink (morse) now
  BB_SetPin(oldpin);						// restore it
end;

function  SearchValIdx(var InpArr:array of real; srchval,Epsilon:real):longint;
// in: search a value 'srchval' in an array. 
// return: index of the value. -1 if not found
var i,idx:longint;
begin  
  idx:=-1; i:=1;
  while i<=Length(InpArr) do
  begin
    if SameValue(InpArr[i-1],srchval,Epsilon) then 
      begin idx:=i-1; i:=Length(InpArr); end;
    inc(i);
  end;
  SearchValIdx:=idx;
end;

function  MovAvg(interval:longword; var InpArr,OutArr:array of real):longint; // moving average
var i,j,l:longint; res:real;
begin
  res:=0; 
  if Length(InpArr)>Length(OutArr) then l:=Length(OutArr) else l:=Length(InpArr); 
  for i:= 1 to l do
  begin
    res:=res+InpArr[i-1];
    if i>=interval then 
    begin
      res:=0;
      for j:= 1 to interval do 
      begin
        res:=res+InpArr[i-interval+j-1];
      end;
      if interval<>0 then OutArr[i-1]:=res/interval else OutArr[i-1]:=0;
    end else OutArr[i-1]:=res/i;
  end;
  MovAvg:=l;
end;

procedure PID_SetTwiddle_KeyName(var TWIDDLE_Struct:PID_Twiddle_t; sect,key:string);
begin
  with TWIDDLE_Struct do
  begin
	twiddle_INI_sect:=sect;
	twiddle_INI_key:= key;
  end; // with
end;
  
procedure PID_SaveTwiddle(var TWIDDLE_Struct:PID_Twiddle_t; K,dK:PID_array_t);
begin
  with TWIDDLE_Struct do
  begin
	if (twiddle_INI_sect<>'') or (twiddle_INI_key<>'') then
	begin
//	  if (twiddle_saveattol<>PID_twiddle_tolNOTsav) then
	  if (twiddle_tol[0]<>twiddle_tol[2]) then
  	  begin
		BIOS_SetIniString(twiddle_INI_sect,twiddle_INI_key,
		  PID_VectorStr(K,			0,PID_nk15,';')+'|'+
		  PID_VectorStr(dK,			0,PID_nk15,';')+'|'+
		  PID_VectorStr(twiddle_tol,0,PID_nk15,';')+'|'+
		GetXMLTimeStamp(now),[]);
  	  end else LOG_Writeln(LOG_ERROR,'PID_SaveTwiddle['+twiddle_INI_sect+'/'+twiddle_INI_key+']: not saved due to switched off tol param');
  	end else LOG_Writeln(LOG_ERROR,'PID_SaveTwiddle['+twiddle_INI_sect+'/'+twiddle_INI_key+']: invalid sect/key pair');
  end; // with
end;
	  	  
function  PID_ReadTwiddle(sect,key:string; var K,dK,tol:PID_array_t):boolean;
// <key>=3.1089;0.0089;76.9491|0.000004245797254;0.000000011910849;0.000005511092205|0.0001;0.00001;0.0|2017-12-12..
var ok:boolean; i:longint; r:PID_float_t; sh:string;
begin
  ok:=false;
	if (sect<>'') or (key<>'') then
	begin
	  sh:=Trimme(BIOS_GetIniString(sect,key,''),3);
	  if sh<>'' then
	  begin
	    ok:=true;
		for i:=0 to 2 do 
		begin
		  if ok then ok:=Str2Num(Select_Item(Select_Item(sh,'|','',1),';','',i+1),r); if ok then K  [i]:=r;
		  if ok then ok:=Str2Num(Select_Item(Select_Item(sh,'|','',2),';','',i+1),r); if ok then dK [i]:=r;
		  if not 		 Str2Num(Select_Item(Select_Item(sh,'|','',3),';','',i+1),tol[i]) then
		  begin
			case i of
				0: tol[i]:=PID_twiddle_saveattol;	// 0:twiddle_saveattol
				2: tol[i]:=PID_twiddle_tolNOTsav;	// 2:PID_twiddle_tolNOTsav
			  else tol[i]:=PID_twiddle_tolerance;	// 1:twiddle_tolerance
			end; // case
		  end; // if
		end;
	  end;
	end else LOG_Writeln(LOG_ERROR,'PID_ReadTwiddle['+sect+'/'+key+']: invalid sect/key pair');  
  PID_ReadTwiddle:=ok;
end;

function  PID_ReadTwiddle(var TWIDDLE_Struct:PID_Twiddle_t; var K,dK,tol:PID_array_t):boolean;
begin 
  with TWIDDLE_Struct do
  begin
    PID_ReadTwiddle:=PID_ReadTwiddle(twiddle_INI_sect,twiddle_INI_key,K,dK,tol);
  end; // with
end;

function  PID_DetAvgs(IdxStart,IdxEnd:longint; var avgnumIst,avgnumPInc:longint):boolean; 
begin
  avgnumIst:=(IdxEnd-IdxStart+1) div 10; // try moving average with lines/10 values
  if avgnumIst>PID_AVGmaxNum_c then avgnumIst:=PID_AVGmaxNum_c; 
  if avgnumIst<PID_AVGminNum_c then avgnumIst:=PID_AVGminNum_c;
  avgnumPInc:=avgnumIst;  
  PID_DetAvgs:=true;
end;

function  PID_FileLoad(StrList:TStringList; filnam,SearchCrit:string; var IdxStart,IdxEnd:longint):boolean;
var _ok:boolean; sh:string;
begin
  _ok:=TextFile2StringList(filnam,StrList,false,sh);
  if _ok	then _ok:=GiveStringListIdx2(StrList,SearchCrit,IdxStart,IdxEnd)
  			else LOG_Writeln(Log_ERROR,'PID_FileLoad: input file '+filnam);
  PID_FileLoad:=_ok;
end;

function  PID_TDR(var TickArr,ValArr,OutTickDeltaArr,OutValArr:array of PID_float_t):longint;
//time derivative response
var i,l:longint;
begin 
  if Length(ValArr)>Length(OutValArr) then l:=Length(OutValArr) else l:=Length(ValArr); 
  if l>Length(TickArr) then l:=Length(TickArr); 
  for i:= 1 to l do
  begin
    OutValArr[i-1]:=0; OutTickDeltaArr[i-1]:=0;
    if i>1 then
    begin
      OutTickDeltaArr[i-1]:=(TickArr[i-1]-TickArr[i-2]);
      if OutTickDeltaArr[i-1]<>0 then 
        OutValArr[i-1]:=	(ValArr [i-1]-ValArr [i-2])/OutTickDeltaArr[i-1];
    end;
  end;
  PID_TDR:=l;
end;

function  PID_VectorStr(var pidarr:PID_array_t; vk,nk:integer; sep:char):string;
var sh:string;
begin 
  sh:=	Num2Str(pidarr[iKp],vk,nk)+sep+
  		Num2Str(pidarr[iKi],vk,nk)+sep+
  		Num2Str(pidarr[iKd],vk,nk);
  PID_VectorStr:=sh;
end;

function  PID_Vector(Kp,Ki,Kd:PID_float_t):PID_array_t;
var i:longint; pa:PID_array_t;
begin
  for i:=1 to Length(pa) do pa[i-1]:=0;
  pa[iKp]:=Kp; pa[iKi]:=Ki; pa[iKd]:=Kd;
  PID_Vector:=pa;
end;

function  PID_DetType(Te,Tb:PID_float_t):integer;
var i:integer; r:PID_float_t;
begin
  i:=ord(PID_Default);
  if not ( (Te=0) or (Tb=0) or IsNaN(Tb) or IsNaN(Te) ) then 
  begin
	r:=Tb/Te;
	i:=ord(P_Default); 						// gut regelbar 		-> P
	if (r<=10)	then i:=ord(PI_Default);	// regelbar 			-> PI	
	if (r<3)	then i:=ord(PID_Default); 	// schlecht regelbar	-> PID
  end;
  PID_DetType:=i;
end;

function  PID_TimAdj(timadjfct:real; var Te,Tb,TSum:PID_float_t):integer;
var res:integer; 
begin
  res:=-1;
  if (not IsNaN(timadjfct)) and (timadjfct>0) then
  begin 
    res:=0;
    if not IsNaN(Te) 	then begin Te:=Te	 *timadjfct; inc(res); end;
    if not IsNaN(Tb) 	then begin Tb:=Tb	 *timadjfct; inc(res); end;
    if not IsNaN(Tsum) 	then begin Tsum:=Tsum*timadjfct; inc(res); end;
  end;
  PID_TimAdj:=res;
end;

function  PID_sim(StrList:TStringList; simnr:integer):real;
//PID_loctusec=4; PID_locsollval=5; PID_locistval=6; 
const hdr1=';;;';
var timadj:real; i:longint;
//Prof. Dr. R. Kessler, FH-Karlsruhe, FB-MN, http://www.home.fh-karlsruhe.de/~kero0001, WendeTangReg3.doc
// returns timebase and a list of values in csv format (for testing)
  procedure tlx(hdr,xs,ys,zs:string); begin StrList.add(hdr+xs+';'+zs+';'+ys); end;
  procedure tl0(x,y:real); begin tlx(hdr1,AdjZahlDE(x/timadj,0,PID_nk8),AdjZahlDE(y,0,PID_nk8),'0'); end;
  procedure tl1(x,y:real); begin tlx(hdr1,AdjZahlDE(x/timadj,0,PID_nk8),AdjZahlDE(y,0,PID_nk8),'1'); end;
  procedure tl2(x,y:real); begin tlx('',  AdjZahlDE(x/timadj,0,PID_nk8),'',AdjZahlDE(y,0,PID_nk8)); end;
begin
  timadj:=1;
  case simnr of
    1:begin
    	for i:=0 to 400 do 
    	begin
    	  if i<10 then tl2((i/10),0) else tl2((i/10),1);
    	end;
      end;
    else 
      begin
  		tl0(0,0); 		tl1(1,0); 		tl1(2,0); 		tl1(3,0); 		tl1(4,0);
  		tl1(5,0.01); 	tl1(6.25,0.05); tl1(7.5,0.15); 	tl1(8.75,0.25); 	
  		tl1(10,0.4); 	tl1(11.25,0.6); tl1(12.5,0.75); tl1(13.75,0.85); 
  		tl1(15,0.9);  	tl1(16.25,0.95);tl1(17.5,0.97); tl1(18.75,0.99);
  		tl1(20,1);
  		for i:=21 to 40 do tl1(i,1);
      end;
  end; // case
  PID_sim:=timadj;
end;
  
function  PID_DetPara(StrList:TStringList; idxStart,idxEnd,smoothdata,smoothtdr,loctim,locist,locSetPoint:longint; StoerSprung,timadjfct:real; var Ks,Te,Tb,Tsum,SampleTimeAvg:PID_float_t; tst:boolean):integer;
//determines Ks,Te,Tb out of a given sensor data (.csv)
//Ks,Te,Tb for feeding PID_GetPara
//Prof. Dr. R. Kessler, FH-Karlsruhe, FB-MN, http://www.home.fh-karlsruhe.de/~kero0001, WendeTangReg3.doc
//StepResponseList.csv	-> using values t(usec) and ist. FieldNum 4&6. SetPoint/soll FieldNum 5
//pwm%;pidnr;cnt;t(usec);soll;ist;avg;preached;t2preach;preachedmax;t2preachmax;pincms;pok;calc;stdev;pon;ppc
//0,45;6;0;0;132;-0,15259;-0,15259;133,28756;552630;133,44015;557774;0,24146382;1;0;7,92544758;1;0
//...
//0,45;6;1081;619469;132;129,85428;129,85428;133,28756;552630;133,44015;557774;0,24146382;1;133,4401502;7,92544758;0;0
var _ok:boolean; res,i,linecnt,idx,avgnumIst,avgnumTDR:longint; 
	maxZ,minZ,tZ,maxXp,tWP,XWP,t1,t2,wt,scaleXp:PID_float_t;
  	A_t,A_td,A_W,A_U,A_X,A_TDR,A_Xp: array of PID_float_t;
begin
  linecnt:=idxEnd-idxStart+1; res:=-1; Ks:=NaN; Te:=Nan; Tb:=NaN; Tsum:=Nan; 
  if (linecnt>0) then
  begin
    Ks:=1; scaleXp:=1; 
    SetLength(A_U,linecnt); 	SetLength(A_X,linecnt); 	SetLength(A_t,linecnt); 
    SetLength(A_TDR,linecnt); 	SetLength(A_Xp,linecnt);  	SetLength(A_W,linecnt);
    SetLength(A_td,linecnt); 
    for i:=idxStart to idxEnd do
    begin // ArrFill 
      _ok:=true;
      if not Str2Num(AdjZahl(Select_Item(StrList[i],';','',loctim)),	 A_t[i-idxStart]) then _ok:=false;	// timeval
      if not Str2Num(AdjZahl(Select_Item(StrList[i],';','',locSetPoint)),A_W[i-idxStart]) then _ok:=false;	// SetPoint
      if not Str2Num(AdjZahl(Select_Item(StrList[i],';','',locist)),	 A_U[i-idxStart]) then _ok:=false;	// istval
      if not _ok then LOG_Writeln(LOG_ERROR,'PID_DetPara['+Num2Str(i,0)+'] value not ok: '+StrList[i]);
    end;
        
    avgnumIST:=smoothdata; if avgnumIST<1 then avgnumIST:=1; // 1=no smoothing
    avgnumTDR:=smoothtdr;  if avgnumTDR<1 then avgnumTDR:=1;
    			
    MovAvg(avgnumIst,A_U,A_X);			// smoothen raw input sensor data
    PID_TDR(A_t,A_X,A_td,A_TDR);	
    SampleTimeAvg:=Mean(A_td)*timadjfct;//writeln('SampleTimeAvg: ',SampleTimeAvg:0:4);
    MovAvg(avgnumTDR,A_TDR,A_Xp);		// smoothen t-derived response
    minZ:=MinValue(A_W);				
    maxZ:=MaxValue(A_W);
    if minZ=maxZ then minZ:=0;
    idx:=SearchValIdx(A_W,maxZ,PID_epsilon_c);
    if idx<0 then tZ:=0 else tZ:=A_t[idx];			// Zeit tZ des Z-Sprungs finden 
    maxXp:=MaxValue(A_Xp);
    idx:=SearchValIdx(A_Xp,maxXp,PID_epsilon_c); 	// Koordinaten tWP und XWP suchen
    if (idx>=0) then
    begin
      maxXp:= maxXp;
      tWP:=A_t[idx]; XWP:=A_X[idx];		// Wendepunkt
      t1:= (XWP-minZ)/maxXp;			// t1= Zeitabschn. unter Wendetangente bis minZ
      t2:= (maxZ-XWP)/maxXp;			// t2= Zeitabschn. oberhalb Wendetangente bis maxZ
      Te:= tWP-t1-tZ;					// Te= Verzugszeit
      Tb:= t1+t2;						// Tb= Ausgleichszeit
      if StoerSprung>0 then 
        Ks:= maxZ/StoerSprung; 			// Ks= Streckenverstärkung = Endwert der Sprungantwort geteilt durch Höhe des Störsprungs.

      if tst then
      begin
//	    create .csv output // overwrite Input StringList !!!!!!!!
	    StrList.clear;
	  
	    scaleXp:=maxZ/maxXp;				// normalize TDR
        StrList.add('time;td;U;cnt;W;U(avg='+Num2Str(avgnumIst,0)+');Xp(scale='+Num2Str(scaleXp,0,PID_nk8)+');WT');
        for i:=1 to linecnt do
        begin            
		  if A_t[i-1]<(tWP-t1) then wt:=minZ else 
		    if A_t[i-1]>(tWP+t2) then wt:=maxZ 
			  else wt:=(A_t[i-1]-(tWP-t1))/Tb*(maxZ-minZ); // calc Wendetangente        
          StrList.add(
        		AdjZahlDE(A_t [i-1],0,PID_nk8)+';'+AdjZahlDE(A_td[i-1],0,PID_nk8)+';'+
        		AdjZahlDE(A_U [i-1],0,PID_nk8)+';'+Num2Str(i-1,0)+';'+
            	AdjZahlDE(A_W [i-1],0,PID_nk8)+';'+AdjZahlDE(A_X   [i-1],0,PID_nk8)+';'+
    	  		AdjZahlDE(A_Xp[i-1]*scaleXp,0,PID_nk8)+';'+
    	  		AdjZahlDE(wt,0,PID_nk8)
				);
        end;  
//    ShowStringList(StrList);   
        scaleXp:=1;
      end;
      
      if PID_TimAdj(SampleTimeAvg,Te,Tb,TSum)>0 then
      begin
        res:=PID_DetType(Te,Tb);		// Determine P/PI/PID
        SAY(LOG_DEBUG,	'tZ/minZ/maxZ/maxXp/SampleTimeAvg/StoerSprung: '+
          				Num2Str(tZ,0,PID_nk8)+' '+Num2Str(minZ,0,PID_nk8)+' '+
          				Num2Str(maxZ,0,PID_nk8)+' '+Num2Str(maxXp,0,PID_nk8)+' '+
          				Num2Str(SampleTimeAvg,0,PID_nk8)+' '+Num2Str(StoerSprung,0,PID_nk8)); 
        SAY(LOG_DEBUG,	'avgnumIST/avgnumTDR: '+Num2Str(avgnumIST,0,PID_nk8)+' '+Num2Str(avgnumTDR,0,PID_nk8)); 
        SAY(LOG_DEBUG,	'WendePunkt['+Num2Str(idx,0)+']: '+
          				Num2Str(tWP,0,PID_nk8)+'/'+Num2Str(XWP,0,PID_nk8));
	    SAY(LOG_DEBUG,	't1/t2: '+Num2Str(t1,0,PID_nk8)+' '+Num2Str(t2,0,PID_nk8));
	    SAY(LOG_DEBUG,	'Ks/Te/Tb/res: '+
	      				Num2Str(Ks,0,PID_nk8)+' '+Num2Str(Te,0,PID_nk8)+' '+
	      				Num2Str(Tb,0,PID_nk8)+' '+Num2Str(res,0));    
      end else LOG_Writeln(LOG_ERROR,'PID_DetPara: timeadj wrong paras');
    end else LOG_Writeln(LOG_ERROR,'PID_DetPara: Xp not found (wrong epsilon?)');
    SetLength(A_U,0);	SetLength(A_X,0); 	SetLength(A_t,0);	SetLength(A_td,0);
    SetLength(A_TDR,0);	SetLength(A_Xp,0);	SetLength(A_W,0);
  end else LOG_Writeln(LOG_ERROR,'PID_DetPara: wrong parameter/empty list');
  PID_DetPara:=res;
end;

function  PID_GetPara(loglvl:t_ErrorLevel; Ks,Te,Tb,Tsum:PID_float_t; Method:PID_Method_t; var Ti,Td:PID_float_t; var K:PID_array_t):integer;
//calcs Kp,Ki,Kd,Ti,Td for feeding PID_Init
//Input:  Statische Verstärkung (Ks), Verzugszeit (Te) und Ausgleichszeit (Tb),
//Input:  Px_SUM (TSum)
//Input:  Einstellregel (Method)
//Output: Ti,Td; Karray:Kp,Ki,Kd
//
//https://de.wikipedia.org/wiki/Faustformelverfahren_(Automatisierungstechnik)
//Script: Spezialgebiete der Steuer- und Regelungstechnik WS 2008/09 FH Dortmund Schriftliche Ausarbeitung Thema: PID - Einstellregeln
//http://www.home.hs-karlsruhe.de/~kero0001/wendtang/wendtang1.html
//Einstellregeln nach Oppelt, ZieglerNichols oder 
//Chien/Hrones/Reswick, Samal:  
//GSA:  gutes Störverhalten, aperiodisch (schwingungsfrei)
//GFA:  gutes Führungsverhalten, aperiodisch (schwingungsfrei)
//GS20: gutes Störverhalten, 20% Überschwingen
//GF20: gutes Führungsverhalten, 20% Überschwingen
//
//Tn/Ti: Nachstellzeit	(DIN19226/DIN EN 60027-6)
//Tv/Td: Vorhaltzeit	(DIN19226/DIN EN 60027-6)
var res:integer;
begin 
  K:=PID_Vector(0,0,0); Ti:=NaN; Td:=NaN; res:=-1;
  if Method IN [P_SUM..PID_SUM_Fast] 
    then if IsNaN(Ks) or IsNaN(Tsum)			or (Ks=0) 			then exit(res)
    else if IsNaN(Ks) or IsNaN(Tb) or IsNaN(Te) or (Ks=0) or (Te=0) then exit(res);
  res:=ord(Method);
  case Method of
      P_Oppelt:			begin K[iKp]:=(1.00/Ks)*(Tb/Te); end; 
      PI_Oppelt:		begin K[iKp]:=(0.80/Ks)*(Tb/Te); Ti:=3.00*Te; end; 
      PID_Oppelt:		begin K[iKp]:=(1.20/Ks)*(Tb/Te); Ti:=2.00*Te; Td:=0.42*Te; end; 
      P_ZiegNich:		begin K[iKp]:=(1.00/Ks)*(Tb/Te); end;
      PI_ZiegNich:		begin K[iKp]:=(0.90/Ks)*(Tb/Te); Ti:=3.33*Te; end; 
      PID_ZiegNich:		begin K[iKp]:=(1.20/Ks)*(Tb/Te); Ti:=2.00*Te; Td:=0.50*Te; end;       
      P_SUM:			begin K[iKp]:=(1.00/Ks); Td:=0; end;
      PD_SUM:			begin K[iKp]:=(1.00/Ks); Td:=0.33*Tsum; end;
      PI_SUM:			begin K[iKp]:=(0.50/Ks); Ti:=0.50*Tsum; Td:=0; end;
      PID_SUM:			begin K[iKp]:=(1.00/Ks); Ti:=0.66*Tsum; Td:=0.167*Tsum; end;
	  PI_SUM_Fast:		begin K[iKp]:=(1.00/Ks); Ti:=0.70*Tsum; Td:=0; end;
      PID_SUM_Fast:		begin K[iKp]:=(2.00/Ks); Ti:=0.80*Tsum; Td:=0.194*Tsum; end;      
      P_CHR_GSA,
      P_CHR_GFA: 		begin K[iKp]:=(0.30/Ks)*(Tb/Te); end;
	  P_CHR_GS20,
	  P_CHR_GF20: 		begin K[iKp]:=(0.70/Ks)*(Tb/Te); end; 
      PI_CHR_GSA:		begin K[iKp]:=(0.60/Ks)*(Tb/Te); Ti:=4.00*Te; end;
      PI_CHR_GFA:		begin K[iKp]:=(0.35/Ks)*(Tb/Te); Ti:=1.20*Tb; end;
	  PI_CHR_GS20:		begin K[iKp]:=(0.70/Ks)*(Tb/Te); Ti:=2.30*Te; end;
      PI_CHR_GF20:		begin K[iKp]:=(0.60/Ks)*(Tb/Te); Ti:=1.00*Tb; end;    
      PID_CHR_GSA:		begin K[iKp]:=(0.95/Ks)*(Tb/Te); Ti:=2.40*Te; Td:=0.42*Te; end;
      PID_CHR_GFA:		begin K[iKp]:=(0.60/Ks)*(Tb/Te); Ti:=1.00*Tb; Td:=0.50*Te; end;    
      PID_CHR_GS20:		begin K[iKp]:=(1.20/Ks)*(Tb/Te); Ti:=2.00*Te; Td:=0.42*Te; end;
      PID_CHR_GF20:		begin K[iKp]:=(0.95/Ks)*(Tb/Te); Ti:=1.35*Tb; Td:=0.47*Te; end; 
	  P_Default,
	  P_SAMAL_GSA,
      P_SAMAL_GFA: 		begin K[iKp]:=(0.30/Ks)*(Tb/Te); end;
      P_SAMAL_GS20,
	  P_SAMAL_GF20:		begin K[iKp]:=(0.71/Ks)*(Tb/Te); end;
      PI_Default,
      PI_SAMAL_GFA:		begin K[iKp]:=(0.34/Ks)*(Tb/Te); Ti:=1.20*Tb; end;
      PI_SAMAL_GF20:	begin K[iKp]:=(0.59/Ks)*(Tb/Te); Ti:=1.00*Tb; end;
	  PI_SAMAL_GSA:		begin K[iKp]:=(0.59/Ks)*(Tb/Te); Ti:=4.00*Te; end;
	  PI_SAMAL_GS20:	begin K[iKp]:=(0.71/Ks)*(Tb/Te); Ti:=2.30*Te; end;
      PID_Default,
      PID_SAMAL_GFA:	begin K[iKp]:=(0.59/Ks)*(Tb/Te); Ti:=1.00*Tb; Td:=0.50*Te; end; 
      PID_SAMAL_GF20:	begin K[iKp]:=(0.95/Ks)*(Tb/Te); Ti:=1.35*Tb; Td:=0.47*Te; end;
      PID_SAMAL_GSA:	begin K[iKp]:=(0.95/Ks)*(Tb/Te); Ti:=2.40*Te; Td:=0.42*Te; end;   
      PID_SAMAL_GS20:	begin K[iKp]:=(1.20/Ks)*(Tb/Te); Ti:=2.00*Te; Td:=0.42*Te; end;
      else				begin K[iKp]:=(1.00/Ks); end;
  end; // case
  if not IsNaN(Ti) then K[iKi]:=K[0]/Ti; 
  if not IsNan(Td) then K[iKd]:=K[0]*Td;
//SAY(loglvl,'PID_GetParaIn ['+GetEnumName(TypeInfo(PID_Method_t),ord(Method))+']: Ks: '+Num2Str(Ks,0,PID_nk8)+' Te: '+Num2Str(Te,0,PID_nk8)+' Tb: '+Num2Str(Tb,0,PID_nk8));
//SAY(loglvl,'PID_GetParaOut['+GetEnumName(TypeInfo(PID_Method_t),ord(Method))+']: Kp: '+Num2Str(K[0],0,PID_nk8)+' Ki: '+Num2Str(K[1],0,PID_nk8)+' Kd: '+Num2Str(K[2],0,PID_nk8)+' Ti: '+Num2Str(Ti,0,PID_nk8)+' Td: '+Num2Str(Td,0,PID_nk8));
  PID_GetPara:=res;
end;

function  CSV_RemFirstSep(strng:string; sep:char):string;
var sh:string;
begin
  sh:=strng;
  if (Length(strng)>0) and (strng[1]=sep) then 
    sh:=copy(strng,2,Length(strng));
  CSV_RemFirstSep:=sh;
end;

function  CSV_RemLastSep(strng:string; sep:char):string;
var sh:string;
begin
  sh:=strng;
  if (Length(strng)>0) and (strng[Length(strng)]=sep) then 
    sh:=copy(strng,1,Length(strng)-1);
  CSV_RemLastSep:=sh;
end;

procedure CSV_MaintList(var csvlst:string; entry:string; addit:boolean);
begin
  if (entry<>'') then
  begin
	if addit then 
	begin
	  if (csvlst<>'') then 
	  begin
		  if (Pos(entry+',',csvlst+',')=0) then csvlst:=csvlst+','+entry; 
	  end else csvlst:=entry;
	end else csvlst:=StringReplace(csvlst+',',entry+',','',[rfReplaceAll]);
	csvlst:=CSV_RemLastSep(csvlst,',');  
  end;
end;

function  CSV_MaintListToogleField(var csvlst:string; entry:string):boolean;
var addit:boolean;
begin
  addit:=(Pos(entry+',',csvlst+',')=0);
  CSV_MaintList(csvlst,entry,addit);
  CSV_MaintListToogleField:=addit;
end;

procedure PID_SimCSV(tl:TStringList; var pid:PID_Struct_t);
// time;td;U;cnt;W;U(avg);Xp;WT
var i:longint; r,OldVal,NewVal,Stellgroesse,SetPoint:PID_float_t; sh:string; 
begin
  with pid do
  begin
	r:=0; OldVal:=0; 
    for i:=1 to tl.count do
    begin
      if i>1 then 
      begin
        sh:=tl[i-1]; 
        if Str2Num(AdjZahl(Select_Item(sh,';','',5)),SetPoint)	and
           Str2Num(AdjZahl(Select_Item(sh,';','',6)),NewVal) 	then
        begin
	      Stellgroesse:=	PID_Calc(pid,SetPoint,NewVal,false);
	      r:=				r+(Stellgroesse/(SetPoint/PID_Ks))*(NewVal-OldVal);
	      tl[i-1]:=tl[i-1]+';'+AdjZahlDE(r,0,PID_nk8)+';'+AdjZahlDE(Stellgroesse*PID_Ks, 0,PID_nk8);
	      OldVal:=NewVal;
	    end;
	  end else tl[i-1]:=tl[i-1]+';X;Y(scale='+Num2Str(PID_Ks,0,4)+')'; // csv Hdr
    end;
  end; // with
end;

procedure PID_TestSim;
var _tl:TStringList; idxa,idxe,avgnumIst,avgnumPInc:longint; Method:PID_Method_t; 
	timadj,SmplTimAvg,StoerSprung,Ks,Te,Tb,Tsum,Ti,Td:PID_float_t; K:PID_array_t;
	pid1:PID_Struct_t;
begin
  _tl:=TStringList.create; 
  timadj:=PID_sim(_tl,0); idxa:=0; idxe:=_tl.count-1; //ShowStringList(_tl); 
  PID_DetAvgs(idxa,idxe,avgnumIst,avgnumPInc);     
  StoerSprung:=1; Method:=PID_Default;
  avgnumIst:=1; avgnumPInc:=1; // demo, no data smoothing.
  PID_DetPara(_tl,idxa,idxe,avgnumIst,avgnumPInc,PID_loctusec,PID_locistval,PID_locsollval,StoerSprung,timadj,Ks,Te,Tb,Tsum,SmplTimAvg,true); 
  PID_GetPara(LOG_INFO,Ks,Te,Tb,Tsum,Method,Ti,Td,K);
  writeln('PID_TestSim Kp:',K[iKp]:0:2,' Ki:',K[iKi]:0:2,' Kd:',K[iKd]:0:2);
//  Kp:=1.1;  Ki:=0.2;  Kd:=0.1;	// Kp=1.1,Ki=0.2,Kd=0.1; //   Kp:=1; Ki:=0; Kd:=0.5;
  PID_Init(pid1,1,500,false,Ks,-25,25,1000,K,PID_Vector(-1.25,1.25,1000),PID_Vector(PID_twiddle_saveattol,PID_twiddle_tolerance,PID_twiddle_tolNOTsav));  
  PID_SimCSV(_tl,pid1);
  ShowStringList(_tl); 
  _tl.free;
end;  

procedure PID_InitTwiddle(var PID_Struct:PID_Struct_t; enab:boolean; itermax:longword; ap,adp,tol:PID_array_t);
begin
//writeln('PID_InitTwiddle['+Num2Str(PID_Struct.PID_nr,0)+']:');
  PID_SetSelfTuning(PID_Struct,enab);
  with PID_Struct.PID_Twiddle do
  begin
	twiddle_best_error:=MaxReal;
	twiddle_sum_dp:=	MaxReal;
	twiddle_sum_dp_old:=MaxReal;
	twiddle_idx:=		0;
	twiddle_state:=		0;
	twiddle_iterations:=0;
	twiddle_intermax:=	itermax;
	twiddle_saved:=		false;
	twiddle_tol:=		tol;
	p:=ap; dp:=adp;  
//	ps:=p; dps:=dp;
  end; // with
  PID_SetTwiddle_KeyName(PID_Struct.PID_Twiddle,'','');
end;
procedure PID_InitTwiddle(var PID_Struct:PID_Struct_t); // try some init values
begin 
  PID_InitTwiddle(PID_Struct,false,500,
  	PID_Vector(0,0,0),
  	PID_Vector(1,1,1),
  	PID_Vector(PID_twiddle_saveattol,PID_twiddle_tolerance,PID_twiddle_tolNOTsav)); 
end;

procedure PID_UpdateError(var PID_Twiddle:PID_Twiddle_t; error:PID_float_t);
var errold:PID_float_t;
begin
  with PID_Twiddle do
  begin
	errold:= 	err[iKp];
	err[iKp]:=	error;
	err[iKi]:= 	err[iKi] + error;
	err[iKd]:= 	error - errold;
  end; // with
end;

function  PID_TotalError(var PID_Struct:PID_Struct_t):PID_float_t;
begin
  with PID_Struct do
  begin
    with PID_Twiddle do
    begin
	  PID_TotalError:= -PID_K[iKp]*err[iKp] - PID_K[iKi]*err[iKi] - PID_K[iKd]*err[iKd];
	end; // with
  end; // with
end;

procedure PID_InitPara(var PID_Struct:PID_Struct_t; K:PID_array_t);
begin 
  with PID_Struct do 
  begin 
	PID_K:=K; PID_Twiddle.err:=PID_Vector(0,0,0);
  end; // with
end;

function  PID_Info(var PID_Struct:PID_Struct_t; fmt:longint):string;
const nkc=15; gkc=nkc+5;
var li:longint; outstr:string;
begin
  outstr:='';
  with PID_Struct do
  begin
	with PID_Twiddle do
	begin
	  case fmt of
	    1:	begin
			  outstr:='Kp,Ki,Kd:    '; 
			  for li:=1 to Length(PID_K)	do outstr:=outstr+Num2Str(PID_K[li-1],gkc,nkc)+' ';
			end;
	    2:	begin
			  outstr:='KpS,KiS,KdS: '; 
			  for li:=1 to Length(PID_Ksav)	do outstr:=outstr+Num2Str(PID_Ksav[li-1],gkc,nkc)+' ';
			end;
	   11: 	begin  // show Twiddle p 
			  outstr:='p  [0-2]:    '; 
			  for li:=1 to Length(p)		do outstr:=outstr+Num2Str(p[li-1],gkc,nkc)+' ';
			end;
	   12: 	begin  // show Twiddle dp 
			  outstr:='dp [0-2]:    '; 
			  for li:=1 to Length(dp) 		do outstr:=outstr+Num2Str(dp[li-1],gkc,nkc)+' ';
			end;
	   13: 	begin  // show Twiddle ps 
			  outstr:='pS [0-2/'+Bool2Dig(sum(ps)<>0)+']:  '; 
			  for li:=1 to Length(ps) 		do outstr:=outstr+Num2Str(ps[li-1],gkc,nkc)+' ';
			end;
	   14: 	begin  // show Twiddle dps 
			  outstr:='dpS[0-2/'+Bool2Dig(sum(dps)<>0)+']:  '; 
			  for li:=1 to Length(dps) 		do outstr:=outstr+Num2Str(dps[li-1],gkc,nkc)+' ';
			end;
	   15: 	begin  // show Twiddle err 
			  outstr:='err[0-2]:  '; 
			  for li:=1 to Length(err) 		do outstr:=outstr+Num2Str(dps[li-1],gkc,nkc)+' ';
			end;
	   else	LOG_Writeln(LOG_ERROR,'PID_Info: unknown fmt: '+Num2Str(fmt,0));
	  end; // case
  	end; // with
  end; // with
  PID_Info:=outstr;
end;

procedure PID_TwiddleCalc(var PID_Struct:PID_Struct_t);
// https://github.com/anupriyachhabra/PID-Controller/blob/master/src/PID.cpp
// https://github.com/antevis/CarND_T2_P4_PID/tree/master/src
// https://www.youtube.com/watch?v=2uQ2BSzDvXs
// http://www.htw-mechlab.de/index.php/numerische-optimierung-in-matlab-mit-twiddle-algorithmus/
// https://junshengfu.github.io/PID-controller/
var _err:PID_float_t;
begin
  with PID_Struct.PID_Twiddle do
  begin
	twiddle_sum_dp_old:=twiddle_sum_dp;
    twiddle_sum_dp:=sum(dp);
	
	if 	(not twiddle_saved) and (twiddle_tol[0]<>twiddle_tol[2]) and
		(twiddle_sum_dp<=twiddle_tol[0]) then 
	begin 
	  ps:=p; dps:=dp; twiddle_saved:=true;
	  SAY(LOG_INFO,'PID_SaveTwiddle['+	Num2Str(PID_Struct.PID_nr,0)+'/'+
	  									twiddle_INI_sect+'/'+twiddle_INI_key+']:'+
	  									' sumdp:'+Num2Str(twiddle_sum_dp,0,PID_nk8)+
	  									' tol:('+PID_VectorStr(twiddle_tol,0,PID_nk8,' ')+')' );
	  PID_SaveTwiddle(PID_Struct.PID_Twiddle,ps,dps);
	end; // keep results
	
	if (twiddle_sum_dp>twiddle_tol[1]) then
	begin	
	  case twiddle_state of
		0:	begin
			  p[twiddle_idx]:=p[twiddle_idx] + dp[twiddle_idx];
    		  twiddle_state:= 1;
			end;			
		1:	begin
			  _err:=PID_TotalError(PID_Struct);
    		  if (_err < twiddle_best_error) then
    		  begin
        		twiddle_best_error:=_err;
				dp[twiddle_idx]:=dp[twiddle_idx] * 1.1;
				twiddle_state:=3;
          	  end
          	  else
          	  begin
				p[twiddle_idx]:=p[twiddle_idx] - 2 * dp[twiddle_idx];
//				if (p[twiddle_idx]<0) then p[twiddle_idx]:=0;
				twiddle_state:=2;
          	  end;
			end;
		2:	begin
			  _err:=PID_TotalError(PID_Struct);
			  if (_err < twiddle_best_error) then
			  begin
				twiddle_best_error:= _err;
				dp[twiddle_idx]:=	 dp[twiddle_idx] * 1.1;
          	  end
          	  else
          	  begin
				 p[twiddle_idx]:=	 p[twiddle_idx] + dp[twiddle_idx];
				dp[twiddle_idx]:=	dp[twiddle_idx] * 0.9;
          	  end;
			  twiddle_state:=3;
			end;
		3:	begin
			  twiddle_idx:=((twiddle_idx+1) mod Length(p));
			  twiddle_state:=0;
			end;
		else LOG_Writeln(LOG_ERROR,'PID_TwiddleCalc, invalid twiddle_idx: '+Num2Str(twiddle_idx,0));
	  end; // case
	end;
	PID_InitPara(PID_Struct,p);
//	SAY(LOG_INFO,'Twiddle['+Num2Str(PID_Struct.PID_nr,0)+']: '+Num2Str(p[0],9,6)+' '+Num2Str(p[1],9,6)+' '+Num2Str(p[2],9,6));
  end; // with
end;

procedure PID_Limit(var Value:PID_float_t; MinOut,MaxOut:PID_float_t);
begin if Value<MinOut then Value:=MinOut else if Value>MaxOut then Value:=MaxOut; end;

procedure PID_SetPrevInput (var PID_Struct:PID_Struct_t; pval:PID_float_t); begin PID_Struct.PID_PrevInput:=pval; end;
procedure PID_SetSelfTuning(var PID_Struct:PID_Struct_t; On_:boolean); begin PID_Struct.PID_Twiddle.twiddle_on:=On_; end;

procedure PID_SetIntImprove(var PID_Struct:PID_Struct_t; On_:boolean); 
// Default: on
// Switches on or off the "Integration Improvement" mechanism of "PID_Struct". 
// This mechanism prevents overshoot/ringing/oscillation 
// due to integration. To be used after "PID_Init"
begin PID_Struct.PID_IntImprove:=On_; end;

procedure PID_SetDifImprove(var PID_Struct:PID_Struct_t; On_:boolean); 
// Default: on
// Switches on or off the "Differentiation Improvement" mechanism of "PID_Struct".
// This mechanism prevents unnecessary correction
// delay when the actual value is changing towards the SetPoint.
// To be used after "PID_Init"
begin PID_Struct.PID_DifImprove:=On_; end;

procedure PID_SetSampleTimeAdjust(var PID_Struct:PID_Struct_t; On_:boolean); 
begin PID_Struct.PID_STimAdj:=On_; end;

procedure PID_ResetIntegrator(var PID_Struct:PID_Struct_t); 
// Re-initialises the PID engine of "PID_Struct" without change of settings
begin PID_Struct.PID_Integrated:=0.0; end;

procedure PID_SetSampleTime(var PID_Struct:PID_Struct_t; New_dT_usec:int64);
var ratio,NewSampleTime:PID_float_t;
begin
  with PID_Struct do
  begin
    if (New_dT_usec>0) and (PID_SampleTime>0) then
    begin
	  NewSampleTime:=	New_dT_usec*1000;	// micro -> milli secs
      ratio:=			NewSampleTime/PID_SampleTime;
      PID_K[iKi]:=		PID_K[iKi]*ratio;
      PID_K[iKd]:=		PID_K[iKd]/ratio;
      PID_SampleTime:=	NewSampleTime;
    end;
  end; // with 
end;

procedure PID_SetMinMaxLimit(var PID_Struct:PID_Struct_t; MinOutput,MaxOutput:PID_float_t);
begin
  with PID_Struct do begin PID_MinOutput:=MinOutput; PID_MaxOutput:=MaxOutput; end; // with
end;

procedure PID_Reset(var PID_Struct:PID_Struct_t);
begin
  with PID_Struct do
  begin 
    PID_ResetIntegrator(PID_Struct); PID_SetPrevInput(PID_Struct,0.0);
	PID_LastError:=0.0; PID_PrevAbsError:=0.0;	PID_cnt:=0;
  end; // with
end;

procedure PID_Init(var PID_Struct:PID_Struct_t; nr:longint; itermax:longword; enab_twiddle:boolean; Ks,MinOutput,MaxOutput,SampleTime_ms:PID_float_t; K,dK,tol:PID_array_t);
// Initialises the PID engine of "PID_Struct"
// Ks = Amplification
// Kp = the "proportional" error multiplier
// Ki = the "integrated value" error multiplier
// Kd = the "derivative" error multiplier
// MinOutput = the minimal value the output value can have (should be < 0)
// MaxOutput = the maximal value the output can have (should be > 0)
begin
  PID_Reset				 (PID_Struct); 	 
  PID_SetIntImprove		 (PID_Struct,true); 
  PID_SetDifImprove		 (PID_Struct,true);	
  PID_SetSampleTimeAdjust(PID_Struct,false);
  PID_SetMinMaxLimit	 (PID_Struct,MinOutput,MaxOutput);
  PID_InitPara			 (PID_Struct,K);
  PID_InitTwiddle		 (PID_Struct,enab_twiddle,itermax,K,dK,tol); // tol=0.00001
  with PID_Struct do
  begin 
    PID_nr:=nr;		PID_Ks:=Ks;   	PID_Delta:=0; PID_Ksav:=K;  		
//	writeln('PID_Init Ks: ',PID_Ks:0:2,' Kp:',PID_Kp:0:2,' Ki:',PID_Ki:0:2,' Kd:',PID_Kd:0:2,' max:',PID_MaxOutput:0:2,' min:',PID_MinOutput:0:2);
	clock_gettime(CLOCK_REALTIME,@PID_Time);
	PID_LastTime:=PID_Time;
	PID_FirstTime:=true;
	PID_SampleTime:=SampleTime_ms; 		PID_LastSampleTime:=PID_SampleTime;
	PID_dT:=round(PID_SampleTime*1000);	PID_LastdT:=PID_dT;
  end;
end;
procedure PID_Init(var PID_Struct:PID_Struct_t; nr:longint; Ks,MinOutput,MaxOutput,SampleTime_ms,tolerance,saveattol:PID_float_t; K:PID_array_t);
begin PID_Init(PID_Struct,nr,500,false,Ks,MinOutput,MaxOutput,SampleTime_ms,K,PID_Vector((K[iKp]*0.25),(K[iKi]*0.2),(K[iKd]*0.01)),PID_Vector(PID_twiddle_saveattol,PID_twiddle_tolerance,PID_twiddle_tolNOTsav)); end;

//http://rn-wissen.de/wiki/index.php/Regelungstechnik
function  PID_Calc(var PID_Struct:PID_Struct_t; Setpoint,InputValue:PID_float_t; twiddle_postpone:boolean):PID_float_t;
// To be called at a regular time interval (e.g. every 100 msec)
// Setpoint: the target value for "InputValue" to be reached
// InputValue: the actual value measured in the system
// Functionresult: PID function of (SetPoint-InputValue) of "PID_Struct",
//   a positive value means "InputValue" is too low  (< SetPoint), the process should take action to increase it
//   a negative value means "InputValue" is too high (> SetPoint), the process should take action to decrease it
var _err,_p,_i,_d:PID_float_t;
begin
  with PID_Struct do
  begin
	clock_gettime(CLOCK_REALTIME, @PID_Time);
	PID_dT	:= MicroSecondsBetween(PID_Time,PID_LastTime);
	if PID_STimAdj and (not PID_FirstTime) and (PID_dT<>PID_LastdT) then PID_SetSampleTime(PID_Struct,PID_dT);
	inc(PID_cnt); 
	_err	:= Setpoint - InputValue;

//	calc p term
	_p		:= PID_K[iKp] * _err;
	
//	calc i term and limit integral windup
	if PID_IntImprove and (Sign(_err)<>Sign(PID_Integrated)) then PID_Integrated := 0.0;		
	PID_Integrated := PID_Integrated + _err;
	PID_Limit(PID_Integrated, PID_MinOutput, PID_MaxOutput);
	_i		:= PID_K[iKi] * PID_Integrated;
	
//	calc d term
	_d		:= PID_K[iKd] * (_err - PID_LastError);
	if PID_DifImprove and (abs(_err)<abs(PID_LastError)) then _d := 0.0; 

	PID_LastError		:= _err;
	PID_Delta			:= (_p + _i + _d);
//	writeln(pid_cnt:2,' err: ',_err:0:4,' res: ',PID_Delta:0:4,' p:',:_p:0:4,' i:',_i:0:4,' d:',_d:0:4);
	PID_Limit(PID_Delta, PID_MinOutput, PID_MaxOutput);
	
	with PID_Struct.PID_Twiddle do
	begin
	  if twiddle_on and (not twiddle_postpone) then
	  begin // PID self tuning
	    inc(twiddle_iterations);
	  	PID_UpdateError(PID_Struct.PID_Twiddle,PID_Delta);
		if (twiddle_iterations>twiddle_intermax) then
		begin
		  PID_TwiddleCalc(PID_Struct);
		  twiddle_iterations:=0;
		end;
	  end;
	end; // with
	
	PID_PrevInput		:= InputValue;
	PID_LastTime		:= PID_Time;
	PID_LastdT			:= PID_dT;
	PID_FirstTime		:= false;
	PID_Calc			:= PID_Delta;
  end; // with
end;

function  PID_Calc(var PID_Struct:PID_Struct_t; Setpoint,InputValue:PID_float_t):PID_float_t;
begin PID_Calc:=PID_Calc(PID_Struct,Setpoint,InputValue,true); end;

procedure PID_TestXX;
//just for demo purposes
//simulate PID. How the to be adjusted Value approaches a Setpoint value
const
  Kp=0.15; Ki=0.1; Kd=0.1;		// PID parameter
  PID_Min=-25; PID_Max=+25;		// MinOutput=-25; MaxOutput=+25
  STim_msec=1000;
  dm_c=13; scale_c=100; ntimes_c=10; errinduct=false;
  PID_SetPoints_c:array[0..(dm_c-1)] of 
    PID_float_t = ( 0, 0.1, 0.2, 0.3, 0.5, 0.7, 0.8, 0.9, 1.1, 1.05, 1.01, 0.9, 0.95);
var loop,n:integer; pid1:PID_Struct_t; NewVal,SetPoint,delta:PID_float_t;
begin
  RPI_HW_Start([InstSignalHandler]);
  PID_Init(pid1,1,1,PID_Min,PID_Max,STim_msec,PID_twiddle_tolerance,PID_twiddle_saveattol,PID_Vector(Kp,Ki,Kd));
  PID_SetIntImprove (pid1,true); PID_SetDifImprove(pid1,true);	// enable improvements
  NewVal:=0; loop:=0; n:=0;
  writeln('PID_Test2 Kp:',Kp:0:2,' Ki:',Ki:0:2,' Kd:',Kd:0:2);
  repeat
    SetPoint:=PID_SetPoints_c[loop]*scale_c;
	delta:=PID_Calc(pid1,SetPoint,NewVal,false);
	{$warnings off} if errinduct then delta:=delta*random; {$warnings on} 
	writeln('PID_Test: SetPoint:',SetPoint:7:2,'  NewVal:',NewVal:7:2,'   delta:',delta:12:8);
	NewVal:=NewVal+delta;
	// action according to NewVal
	sleep(STim_msec); 
	inc(n); if n>=ntimes_c then begin n:=0;	inc(loop); if loop>=dm_c then loop:=0; end;
  until terminateProg;
end;

procedure PID_Test;
//just for demo purposes
//simulate PID. How the to be adjusted Value approaches a Setpoint value
const
  Kp=1.1;  Ki=0.2;  Kd=0.1;		// PID parameter
  PID_Min=-25; PID_Max=+25;		// MinOutput=-25; MaxOutput=+25
  STim_msec=1000;
  dm_c=8; scale_c=47; ntimes_c=16; errinduct=false;
  PID_SetPoints_c:array[0..(dm_c-1)] of PID_float_t = ( 1, 0, -1, 0, 2, 3, -1, 0 );
var loop,n:integer; pid1:PID_Struct_t; NewVal,SetPoint,delta:PID_float_t;
begin
  RPI_HW_Start([InstSignalHandler]);
  PID_Init(pid1,1,1,PID_Min,PID_Max,STim_msec,PID_twiddle_tolerance,PID_twiddle_saveattol,PID_Vector(Kp,Ki,Kd));
  PID_SetIntImprove (pid1,true); PID_SetDifImprove(pid1,true);	// enable improvements
  NewVal:=0; loop:=0; n:=0;
  writeln('PID_Test2 Kp:',Kp:0:2,' Ki:',Ki:0:2,' Kd:',Kd:0:2);
  repeat
    SetPoint:=PID_SetPoints_c[loop]*scale_c;
	delta:=PID_Calc(pid1,SetPoint,NewVal,false);
	{$warnings off} if errinduct then delta:=delta*random; {$warnings on} 
	writeln('PID_Test: SetPoint:',SetPoint:7:2,'  NewVal:',NewVal:7:2,'   delta:',delta:12:8);
	NewVal:=NewVal+delta;
	// action according to NewVal
	sleep(STim_msec); 
	inc(n); if n>=ntimes_c then begin n:=0;	inc(loop); if loop>=dm_c then loop:=0; end;
  until terminateProg;
end;

function  CL_Compose(cmdLine:string):string;	
//inspired by Wolverrum
  function  _AddQuotes(str:string):string;
  var sh:string;
  begin
    if Pos(' ',str)>0 then sh:=Format('"%s"',[str]) else sh:=str;
    _AddQuotes:=sh;
  end;
  
var i:longword; sh:string;
begin
  sh:='';
  if Length(cmdLine)=0 then
  begin
    for i:= 1 to ParamCount() do
    begin
      if sh='' 	then sh:=_AddQuotes(ParamStr(i))
            	else sh:=Format('%s %s',[sh,_AddQuotes(ParamStr(i))]);
    end;
  end else sh:=cmdLine;
  CL_Compose:=sh;
end;

function  CL_Parse(cmdLine:string):t_CLOptions;	// Posix CommandLine Parser
// inspired by Wolverrum
const
  _SpaceChars = [#$20,#$09,#$0D,#$0A];
  _EqChars    = [':','='];
  _QChars     = ['''','"'];

  procedure _SkipSpace(var str:string; var i:longword);
  begin while cmdLine[i] IN _SpaceChars do inc(i) end;

  function  _Getstring (var str:string; var i:longword):string;
  var chPos:longword; sh:string;
  begin
    chPos:=i+1;
    while (str[chPos]<>str[i]) AND (chPos<=Length(str)) do inc(chPos);
    sh:=copy(str,i+1,chPos-i-1);
    if str[i]<>str[chPos] then 
      Log_Writeln(Log_ERROR,Format('CL_Parse: string {%c}[[ %s ]]{%c} must be have quote on the end',[str[i],sh,str[chPos]]));
    i:=chPos+1;
    _Getstring:=sh;
  end;

  function  _GetValue(var str:string; var i:longword):string;
  var chPos:longword; sh:string;
  begin
    chPos:=i;
    while (NOT (str[chpos] IN _SpaceChars)) AND (chPos<=Length(str)) do inc(chPos);
    sh:=copy(str,i,chPos-i+1);
    i:=chPos;
    _GetValue:=sh;
  end;

  function  _GetOptionName(var str:string; var i:longword):string;
  var chBeg,chend:longword; sh:string;
  begin
    if str[i+1]='-' then chBeg:=i+2 else chBeg:=i+1;
    chend:=chBeg;
    while (NOT (str[chend] IN (_EqChars+_SpaceChars))) AND (chend<=Length(str)) do inc(chend);
    sh:=copy(str,chBeg,chend-chBeg);
    i:=chend;
    _GetOptionName:=sh;
  end;

  function  _GetOptionValue(var str:string; var i:longword):string;
  var chPos:longword; sh:string;
  begin
    chPos:=i;
    if str[i] IN _EqChars then 
    begin
      chPos:=i+1;
      if str[i+1] IN _QChars then sh:=_Getstring(str,chPos) 
      						 else sh:=_GetValue (str,chPos);
    end;
    i:=chPos;
    _GetOptionValue:=sh;
  end;
  
var i,pPos:longword; _CLO:t_CLOptions;
begin
  pPos:=0; i:=1; SetLength(_CLO,0);
  while i<Length(cmdLine) do 
  begin
    _SkipSpace(cmdLine,i);
    case cmdLine[i] OF
    '''','"': 	begin
            	  inc(pPos);
				  SetLength(_CLO,Length(_CLO)+1);
				  with _CLO[Length(_CLO)-1] do
				  begin
				    Name:= Format('%d',[pPos]);
				    Value:=_Getstring(cmdLine,i);
				  end;
				end;
    '-','/' :  	begin
				  SetLength(_CLO,Length(_CLO)+1);
				  with _CLO[Length(_CLO)-1] do
				  begin
					Name:= _GetOptionName (cmdLine,i);
					Value:=_GetOptionValue(cmdLine,i);
				  end;
          		end;
    else		begin
				  inc(pPos); 
				  SetLength(_CLO,Length(_CLO)+1);
				  with _CLO[Length(_CLO)-1] do 
				  begin
					Name:= Format('%d',[pPos]);
					Value:=_GetValue(cmdLine,i);
            	  end;
          		end;
    end; // case
  end; // while
  CL_Parse:=_CLO;
end;

function  CL_OptGiven(var cl_opts:t_CLOptions; opt:string):integer;
// returns index. if index is >=0, then 'opt' was given 
var idx,i:integer;
begin
  idx:=-1; i:=1;
  while (i<=Length(cl_opts)) do
  begin
    if (opt=cl_opts[i-1].Name) then begin idx:=i-1; i:=Length(cl_opts); end;
    inc(i);
  end; // while
  CL_OptGiven:=idx;	
end;

procedure CL_Test;	// CommandLine Parser Test
var i:integer; opts:t_CLOptions; sh:string;
begin
  sh:='-oabc -h --def="ijk lmno" eben abc -k "klm xyz" --help /? '; // simulates given commandline parameter
  writeln(sh); writeln;
//writeln(CL_Compose(sh)); writeln;
  opts:=CL_Parse(sh);
  
  for i:= 1 to Length(opts) do
  begin
    writeln(i,'.:',opts[i-1].Name,'=',opts[i-1].Value);
  end;
  writeln;
  
  i:=CL_OptGiven(opts,'def');
  if i>=0 then writeln('given option "',opts[i].Name,'" with value "',opts[i].Value,'"');
  writeln('is help option given?: ',(CL_OptGiven(opts,'help')>=0) or (CL_OptGiven(opts,'?')>=0));
end;
 
procedure RPI_hal_exit;
begin
//writeln('Exit unit RPI_hal+');
  PtrRPI_SignalRoutine:=nil;
  if ExitCode<>0 then 
  begin 
    LOG_Writeln(LOG_ERROR,'ExitCode: '+FPC_ErrDesc(ExitCode)); 
    if ExitCode=217 then LOG_Writeln(LOG_ERROR,'RPI_hal_exit: maybe RPI_hal was not initialized, check usage of RPI_HW_Start');
  end;
  if RPI_platform_ok then
  begin
    TRIG_End(-1); 
    ENC_End(-1);
	SERVO_End(-1);
	ERR_END(-1);
    SPI_Bus_Close_All;
    I2C_Close_All;
    RPI_FW_close;
    MMAP_end;
  end;
//writeln('Exit unit RPI_hal-');
  BIOS_EndIniFile;
  RpiMaintCmd.free;
  if (wdog.Hndl>=0) then 
  begin
//	SAY(LOG_WARNING,'LNX_WDOG['+Num2Str(wdog.Hndl,0)+']: do not forget to close WDOG with LNX_WDOG(0) at end of your application');
	LNX_WDOG(WDOG_Close);	// DISABLE&close WDOG device
  end;
  if _OnExitShowRuntime then SAY(LOG_INFO,LOG_GetEndMsg(''));
  MSG_HUB_ptr:=nil; CURL_ProgressUpdateHook_ptr:=nil;
  LOG_LevelColor(false);
//say(log_info,'RPI_hal_exit-')
end;

procedure RPI_SignalHandlerErrExit(errno:longint);
begin
  LOG_Writeln(LOG_ERROR,'RPI_SignalHandlerErrExit['+Num2Str(errno,0)+']: '+LNX_ErrDesc(errno));
end;

function  RPI_SignalRoutine(sig:cint):integer;
// My HandlerRoutine: Installation: PtrRPI_SignalRoutine:=@RPI_SignalRoutine;
begin
//do something with 'sig'
  RPI_SignalRoutine:=0;
end;

procedure RPI_SignalHandler(sig:cint); cdecl;
begin
  LOG_Writeln(LOG_ERROR,'RPI_SignalHandler: receiving signal: '+Num2Str(sig,0));
  case sig of
	SIGUSR1:begin	// set errorlevel from external e.g. kill -USR1 <pid>
			  LOG_Level(LOG_INFO); 
			  SAY_Level(LOG_INFO); 
			end;
	SIGUSR2:begin	// set errorlevel from external e.g. kill -USR2 <pid>
			  LOG_Level(LOG_WARNING); 
			  SAY_Level(LOG_WARNING); 
			end;
	SIGTERM,SIGINT,
	SIGHUP:	terminateProg:=true;
	else 	begin
			  LOG_WRITELN(LOG_WARNING,'RPI_SignalHandler: unregistered signal ('+Num2Str(sig,0)+'), set variable terminateProg');
			  terminateProg:=true;
			end;
  end; // case
  if (PtrRPI_SignalRoutine<>nil) then PtrRPI_SignalRoutine(sig);
end;

function  RPI_Init_Allowed:boolean;
var ok:boolean; i:longint;
begin
  ok:=false;
  for i:=1 to ParamCount do if Upper(ParamStr(i))='-RPIHAL=HWINIT' then ok:=true;  
  RPI_Init_Allowed:=ok;
end;

function  RPI_HW_Start(initpart:s_initpart; p1,p2:string):boolean;
var ok,gpio_only:boolean; _flgtodo:s_initpart; sh:string; // j:t_initpart;
begin
  ok:=true; _flgtodo:=initpart; RPI_HW_initpart:=initpart;
//for j IN initpart do SAY(LOG_WARNING,GetEnumName(TypeInfo(t_initpart),Ord(j)));

  if (InitOnExitShowRuntime 	IN RPI_HW_initpart) then 
  begin
    _flgtodo:=_flgtodo-[InitOnExitShowRuntime];
    _OnExitShowRuntime:=true;
  end;
  
  if (InitCertServer			IN RPI_HW_initpart) then 
  begin
	_flgtodo:=_flgtodo-[InitCertServer];
	if (not CertPack[CertPackServer].ok) then
	begin // just start it, if not already started
	  ok:=LNX_CertStartPack(
	  		CertPack[CertPackServer],
  			'ServerCert',
  			cert1_crtORpem_c,
  			cert1_key_c,
  			PrepFilePath(cert_crt_dir_c),
  			cert1_combined_c,
  			p2,CT_ssl );
	  if ok then
	  begin
  	  	if not CertPack[CertPackRPIMaint].ok then 
  	  	  CertPack[CertPackRPIMaint]:=CertPack[CertPackServer];
  	 	LNX_CertPackShow(LOG_INFO,CertPack[CertPackServer]);
  	  end; // else LOG_Writeln(LOG_ERROR,'LNX_CertStartPack: can not start cert pack '+CertPack[CertPackServer].desc);
	end;
  end;
  
  if (InitCertLetsEncrypt		IN RPI_HW_initpart) then 
  begin
    _flgtodo:=_flgtodo-[InitCertLetsEncrypt];
	if (not CertPack[CertPackLetsEncrypt].ok) then
	begin // just start it, if not already started, para = domain
	  if (p1<>'') then 
	  begin
	  	sh:=letsencryptdir_c+'/'+p1;
	  	ok:=LNX_CertStartPack(
	  		CertPack[CertPackLetsEncrypt],
  				'Lets Encrypt ('+p1+')',
  				PrepFilePath(sh+'/fullchain.pem'),	// PrepFilePath(sh+'/cert.pem'),
  				PrepFilePath(sh+'/privkey.pem'),
  				PrepFilePath(sh+'/fullchain.pem'),	// PrepFilePath(sh+'/chain.pem'),
  				PrepFilePath(sh+'/combined.pem'),
  				p2,CT_ssl );
	  	if ok then
	  	begin
  	  	  if not CertPack[CertPackRPIMaint].ok then 
  	  	  	CertPack[CertPackRPIMaint]:=CertPack[CertPackLetsEncrypt];
  	 	  LNX_CertPackShow(LOG_INFO,CertPack[CertPackLetsEncrypt]);
  	 	end; // else LOG_Writeln(LOG_ERROR,'LNX_CertStartPack: can not start cert pack '+CertPack[CertPackLetsEncrypt].desc);
  	  end else LOG_Writeln(LOG_ERROR,'LNX_CertStartPack: Lets Encrypt, missing domain name');
	end;
  end;
  
  if (InitCertSnakeOil			IN RPI_HW_initpart) then 
  begin
    _flgtodo:=_flgtodo-[InitCertSnakeOil];
	if (not CertPack[CertPackSnakeOil].ok) then
	begin // just start it, if not already started
	  ok:=LNX_CertStartPack(
	  		CertPack[CertPackSnakeOil],
  			'snakeoil (self signed)',
  			cert0_crtORpem_c,
  			cert0_key_c,
  			cert0_crtORpem_c,	// PrepFilePath(cert_crt_dir_c),
  			cert0_combined_c,
  			p2,CT_ssl );
	  if ok then
	  begin
  	  	if not CertPack[CertPackRPIMaint].ok then 
  	  	  CertPack[CertPackRPIMaint]:=CertPack[CertPackSnakeOil];
  	 	LNX_CertPackShow(LOG_INFO,CertPack[CertPackSnakeOil]);
  	  end else LOG_Writeln(LOG_ERROR,'LNX_CertStartPack: can not start cert pack '+CertPack[CertPackSnakeOil].desc);
	end;
  end;
  
  if ok and (UPDAuthDBDateTime	IN RPI_HW_initpart) then 
  begin
	_flgtodo:=_flgtodo-[UPDAuthDBDateTime];
	{$IFDEF UNIX} 
	  LNX_UsrAuthModDateTime:=GetFileAge(LNX_ShadowFile);
	{$ENDIF}
  end;
  
  if (InstSignalHandler	IN RPI_HW_initpart) then 
  begin
	_flgtodo:=_flgtodo-[InstSignalHandler];
	{$IFDEF UNIX} 
  	  new(na); new(oa); terminateProg:=false;
  	  na^.sa_Handler:=SigActionHandler(@RPI_SignalHandler);
  	  fillchar(na^.Sa_Mask,sizeof(na^.sa_mask),#0);
  	  na^.Sa_Flags:=0;
	  {$ifdef Linux}               // Linux specific
	  	na^.Sa_Restorer:=nil;
	  {$endif}
	  if (fpSigAction(SIGALRM,na,oa)<>0) then RPI_SignalHandlerErrExit(fpgeterrno);
	  if (fpSigAction(SIGHUP, na,oa)<>0) then RPI_SignalHandlerErrExit(fpgeterrno);
	  if (fpSigAction(SIGTERM,na,oa)<>0) then RPI_SignalHandlerErrExit(fpgeterrno);
	  if (fpSigAction(SIGINT, na,oa)<>0) then RPI_SignalHandlerErrExit(fpgeterrno);
	  if (fpSigAction(SIGUSR1,na,oa)<>0) then RPI_SignalHandlerErrExit(fpgeterrno);
	  if (fpSigAction(SIGUSR2,na,oa)<>0) then RPI_SignalHandlerErrExit(fpgeterrno);
	{$ENDIF}
  end;
  
  if (InitWDOG IN RPI_HW_initpart) or (InitWDOGnoThread IN RPI_HW_initpart) then
  begin
	{$IFDEF UNIX} 
  	  _flgtodo:=_flgtodo-[InitWDOG];
      LNX_WDOG_Init(wdog);
	  if LNX_WDOG_Start then 
		begin
	  	LNX_WDOG(WDOG_GSup);	 	// WDIOC_GETSUPPORT
	  	LNX_WDOG(WDOG_STO);			// Set timeout to default (15 sec)
	  	LNX_WDOG(WDOG_BSTAT);	 	// Get last boot stat
	  	if not (InitWDOGnoThread	IN RPI_HW_initpart)
	  	  then Thread_Start(wdog.ThreadCtrl,@LNX_WDOG_Thread,nil,0,0)
	  	  else _flgtodo:=_flgtodo-[InitWDOGnoThread];							
	  end else LOG_Writeln(LOG_ERROR,'WDOG: can not init');
	{$ELSE}
	  _flgtodo:=_flgtodo-[InitWDOG,InitWDOGnoThread];
	{$ENDIF}
  end;
  		
//rpi HW dependent:
  if (_flgtodo<>[]) then
  begin
	ok:=RPI_platform_ok;  gpio_only:=false; 
(*if (InitGPIOonly IN RPI_HW_initpart) then 
  begin // not supported, does not work on rpi3
    RPI_HW_initpart:=[InitGPIO]; gpio_only:=true;
    if (StartShutDownWatcher 	IN initpart) then RPI_HW_initpart:=RPI_HW_initpart+[StartShutDownWatcher];
  end; *)
  
    if ok and (InitCreateScript IN RPI_HW_initpart) then
    begin
	  _flgtodo:=_flgtodo-[InitCreateScript];
	  {$IFDEF UNIX} 
    	GPIO_create_int_script(int_filn_c); // no need for it. Just for convenience 
      {$ENDIF} 
    end;

  	if ok and (InitRPIfw 		IN RPI_HW_initpart) then 
  	begin
  	  _flgtodo:=_flgtodo-[InitRPIfw];
      RPI_FW_open;
      if not RPI_FW_Info(TAG_STATUS_REQUEST,TAG_GET_FIRMWARE_REVISION,cpu_fw) then cpu_fw:='';
	end;
  
  	if (InitI2C IN RPI_HW_initpart) or (InitSPI IN RPI_HW_initpart) 
      then RPI_HW_initpart:=RPI_HW_initpart+[InitGPIO]; // GPIO is mandatory
    
  	if ok and (InitGPIO 			IN RPI_HW_initpart) or 
  	  (StartShutDownWatcher 		IN RPI_HW_initpart) then 
  	begin
  	  _flgtodo:=_flgtodo-[InitGPIO];
  	  ok:=(MMAP_start(gpio_only)=0);
  	end;

  	if ok and (InitI2C				IN RPI_HW_initpart) then
  	begin 
  	  _flgtodo:=_flgtodo-[InitI2C];
      ok:=(not restrict2gpio);
      if ok then I2C_Start else Log_Writeln(Log_ERROR,'RPI_HW_Start: can not start I2C, try with sudo');
  	end;

  	if ok and (InitSPI				IN RPI_HW_initpart) then 
  	begin
  	  _flgtodo:=_flgtodo-[InitSPI];
      ok:=(not restrict2gpio);
      if ok then SPI_Start else Log_Writeln(Log_ERROR,'RPI_HW_Start: can not start SPI, try with sudo');
  	end;
    
  	if ok and (StartShutDownWatcher IN RPI_HW_initpart) then 
  	begin
  	  _flgtodo:=_flgtodo-[StartShutDownWatcher];
  	  ok:=RPI_ShutDownStart;
  	end;
      
  	if not ok then
  	begin
      if not RPI_run_on_known_hw 
      	then Log_Writeln(Log_ERROR,'RPI_hal: not running on supported rpi HW');
//	  	else Log_Writeln(Log_ERROR,'RPI_hal: supported min-/maximum kernel #'+Num2Str(supminkrnl,0)+' - #'+Num2Str(supmaxkrnl,0)+' ( uname -a )');

      if (InitHaltOnError 			IN RPI_HW_initpart) then 
	  begin
	  	_flgtodo:=_flgtodo-[InitHaltOnError];
        LOG_Writeln(LOG_ERROR,'RPI_hal: can not initialize MemoryMap.');
//	    Halt(1);
      end;
	end;
  end;

  RPI_HW_Start:=ok;
end;
function  RPI_HW_Start(initpart:s_initpart):boolean; begin RPI_HW_Start:=RPI_HW_Start(initpart,'',''); end;

function  RPI_HW_Start:boolean; 
begin 
  RPI_HW_Start:=RPI_HW_Start([InitHaltOnError,InitRPIfw,InitGPIO,InitI2C,InitSPI,UPDAuthDBDateTime]);  // start all HW
end;

procedure inivar;
var i,j:integer;
begin
  RPI_ProgramStartTime:=now; 	_OnExitShowRuntime:=false; 
  terminateProg:=false;			PtrRPI_SignalRoutine:=nil;
  LNX_sudo(false);
  MSG_HUB_ptr:=nil;				CURL_ProgressUpdateHook_ptr:=nil;
  rpi_fw_api.hndl:=-1; 			GPU_MEM_BASE:=0;
  LOG_LevelColor(true);
  LOG_Level(LOG_Warning); 		SAY_Level(LOG_INFO);

  with IP_Infos do
  begin
  	idx:=0; init:=false; samesubnet:=false; hostname:=''; devlst:='';
	IPInfo_Init(ifwlan_c,	IP_Info[0]);	IP_Info[0].alias:=ifwlan_c;
	IPInfo_Init(ifeth_c,	IP_Info[1]);	IP_Info[1].alias:=ifeth_c;
	IPInfo_Init(ifuap_c,	IP_Info[2]);	IP_Info[2].alias:=ifuap_c;
  end; // with
  
  with IniFileDesc do begin inifilename:=''; ok:=false; end;
 
  BIOS_ReadIniFile(PrepFilePath(AppDataDir_c+'/'+ApplicationName+'/'+ApplicationName+'.ini'));
  BIOS_SetDfltFlags([]);
  BIOS_SetDfltSection(Upper(DfltSect_c));
  LOG_Level(Str2LogLvl(BIOS_GetIniString('LOGERRLVL','WARNING'))); 
  SAY_Level(Str2LogLvl(BIOS_GetIniString('LOGAPPLVL','INFO'))); 
//LOG_Level(LOG_Warning); 		
//SAY_Level(LOG_INFO);
  BIOS_SetDfltSection(Upper(ApplicationName));
  cpu_fw:='';
  RpiMaintCmd:=TIniFile.Create('');
  RPI_MaintSetVersions(0,0);	// disable VersionCheck@RPI_Maint PKGInstall
  with RPI_Temps do
  begin
  	TempInfo:=''; TempIdx:=1; TempMax:=RPI_TempAlarmCelsius_c;
	for i:= 1 to 2 do begin Temp[i]:=NaN; TempLvl[i]:=LOG_NONE; end;
	TempUnit[1]:='''C'; TempUnit[2]:='&#x2103;';
  end; // with
//RPI_Temp(false);
  SetUTCOffset;  // set _TZlocal 
  mem_fd:=-1; mmap_arr:=nil; cpu_rev_num:=0; GPIO_map_idx:=2; 
  
  eeprom_SetAddr(eeprom_devadr_c);
  for i:=0 to spi_max_bus do for j:=0 to spi_max_dev do spi_dev[i,j].spi_fd:=-1;
  if not clock_getres(CLOCK_REALTIME,@rpi_timespecresolution)=0 then
  begin
    rpi_timespecresolution.tv_nsec:=1;
    Log_Writeln(Log_ERROR,'Get_CPU_INFO_Init: can not get timeresolution');
  end;
  LNX_UsrAuthModDateTime:=0;
  LNX_WDOG_Init(wdog);
  for i:= CertPackRPIMaint to CertPackLast do LNX_CertInitPack(CertPack[i],i);
//LNX_CertInitPack(CertPackServer);
//LNX_CertInitPack(CertPackLetsEncrypt);
  {$IFDEF WINDOWS} SDcard_root_hdl:=3; {$ELSE} SDcard_root_hdl:=AddDisk('/'); {$ENDIF} 
end;

begin
//writeln('Enter unit rpi_hal');
  AddExitProc(@RPI_hal_exit);
  inivar;
  Get_CPU_INFO_Init; 
  BB_pin:=RPI_status_led_GPIO;
//RPI_ShutDownInit(-1);			// just init data struct, no HW-Pin
  MORSE_speed(-1);				// set to default speed 10WpM=50BpM	-> 120ms 
  IO_Init_Const;
  RPI_HW_initpart:=[];
  if RPI_Init_Allowed then RPI_HW_Start;
//writeln('Leave unit rpi_hal');
end.
