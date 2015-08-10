CON
  _clkmode = xtal1 + pll16x                                               
  _xinfreq = 5_000_000

  baud  = 9600
  
  ESP8266_RXPIN = 10
  ESP8266_TXPIN = 9 
  
  SHT_CLK = 12
  SHT_DATA = 13
     
  CO2_RX          = 18                   {RX CO2 sensor shared pin }
  CO2_TX_1        = 3     
  CO2_TX_2        = 4
  CO2_TX_3        = 5
  CO2_TX_4        = 6
  CO2_TX_5        = 7
  CO2_TX_6        = 8
  CO2_TX_7        = 19
  
  CNT_PIN         = 31
  NCO_FREQ        = 610         '($8000)(80x10^6)/2^32 = 610.3516Hz                           
  FREQ_610        = $8000       ' AN001-P8X32ACounters-v2.0_2.pdf (page 6) 
  
VAR
  long stack1[128]
  byte buffer[10]   
  long Co2_1, Co2_2, Co2_3, Co2_4, Co2_5, Co2_6, Co2_7, value
  byte  temp[32]                               {input temp }
  byte  lv[32]                                 {input lv }
  long tempC,tempC1,tempC2,tempC3              {global temp vars }
  long lv1,lv2,lv3                             {global lv vars }     
       
OBJ  
  serial        : "FullDuplexSerial_2k"
  term          : "FullDuplexSerial_2k"
  K30           : "Parallax Serial Terminal"
  sht           : "Sensirion_full"         { temp/lv sensor control object }
  f             : "Float32"                  { Math object }

PUB main 

  term.start(31,30,00,baud)
  term.str(string("Booting system",13))  
    
  term.str(string("Start ESP connection",13))
  serial.start(ESP8266_TXPIN,  ESP8266_RXPIN, 00, baud)
  waitcnt(clkfreq*4+cnt)
  
  term.str(string("Making sure ABC function is disabled in all K30 sensors",13))
  disable_all_abc
  
  term.str(string("Connect to Wifi",13))
  get_wifi

  term.str(string("setting up clock and then do my job",13))
  ctrb := %00100_000 << 23 + 1 << 9 + CNT_PIN   'Setup a 610 Hz square wave on CNT_PIN
  frqb := FREQ_610 
  dira[CNT_PIN] := 1
  ctra := %01010 << 26 + CNT_PIN   'Positive edge counter on CNT_PIN
  frqa := 1
  cognew(send_data_to_db,@stack1)    
  repeat
  
    if (60 - phsa/NCO_FREQ <  1)
      frqa := phsa:= 0
      ctrb := %00100_000 << 23 + 1 << 9 + CNT_PIN   'Setup a 610 Hz square wave on CNT_PIN
      frqb := FREQ_610 
      dira[CNT_PIN] := 1
      ctra := %01010 << 26 + CNT_PIN   'Positive edge counter on CNT_PIN
      frqa := 1
      cognew(send_data_to_db,@stack1) 

PUB send_data_to_db

    Read_Sensors
    send_data(long[@Co2_1], long[@Co2_2], long[@Co2_3], long[@Co2_4], long[@Co2_5], long[@Co2_6], long[@Co2_7], long[@tempC3], long[@lv3])    
    cogstop(cogid)
    
PUB send_data(sensor_1, sensor_2, sensor_3, sensor_4, sensor_5, sensor_6, sensor_7, temp_sensor, lv_sensor)  
  
  sendCommand(string("conn=net.createConnection(net.TCP, 0)"))
  waitcnt(clkfreq+cnt)
  getResponse
          
  sendCommand(string("conn:on(",34,"receive",34,", function(conn, payload) print(payload) end)"))
  waitcnt(clkfreq+cnt)
  getResponse
                      
  sendCommand(string("conn:connect(80,",34,"192.168.2.50",34,")"))
  waitcnt(clkfreq+cnt)
  getResponse
   
  serial.str(string("conn:send(",34,"GET /index2.php?sensor1="))
  serial.dec(sensor_1)
  serial.str(string("&sensor2="))
  serial.dec(sensor_2)
  serial.str(string("&sensor3="))
  serial.dec(sensor_3)
  serial.str(string("&sensor4="))
  serial.dec(sensor_4)
  serial.str(string("&sensor5="))
  serial.dec(sensor_5)
  serial.str(string("&sensor6="))
  serial.dec(sensor_6)
  serial.str(string("&sensor7="))
  serial.dec(sensor_7)  
  serial.str(string("&temp="))
  serial.dec(temp_sensor)
  serial.str(string("&lv="))
  serial.dec(lv_sensor)    
  serial.str(string(" HTTP/1.1\r\n",34,")"))
  waitcnt(clkfreq+cnt)  
    
  sendCommand(string("conn:send(",34,"Host: boekhouding.dev\r\n",34,")"))
  waitcnt(clkfreq+cnt)
  sendCommand(string("conn:send(",34,"Accept: */*\r\n",34,")"))
  waitcnt(clkfreq+cnt)
  sendCommand(string("conn:send(",34,"\r\n",34,")"))
  getResponse
  
  sendCommand(string("conn:close()"))     
  waitcnt(clkfreq*10+cnt)


PUB  get_wifi

  sendCommand(string("node.restart()"))
  getResponse
  waitcnt(clkfreq*2+cnt)

  sendCommand(string("wifi.setmode(wifi.STATION)"))
  getResponse
  waitcnt(clkfreq+cnt)

  sendCommand(string("wifi.sta.config(",34,"SSID",34,",",34,"PASSWORD",34,")"))
  getResponse
  waitcnt(clkfreq+cnt)

  sendCommand(string("wifi.sta.connect()"))
  getResponse
  waitcnt(clkfreq+cnt)
  
  sendCommand(string("print(wifi.sta.getip())"))
  waitcnt(clkfreq*3+cnt)
  getResponse
  
PRI getResponse | i, a

  repeat a from 0 to 9
    buffer[a]:=0        
          
  i:= serial.rxtime(5000)
  repeat while i <> -1
    term.tx(i)
    i:= serial.rxtime(5000)

  return false

PRI sendCommand(strng) | i
  serial.str(strng)
  serial.tx(13)
  serial.tx(10) 

PUB disable_all_abc

  K30.StartRxTx(CO2_TX_1, CO2_RX, 0, baud)
  Disable_ABC_fast
  K30.Stop

  K30.StartRxTx(CO2_TX_2, CO2_RX, 0, baud)
  Disable_ABC_fast
  K30.Stop

  K30.StartRxTx(CO2_TX_3, CO2_RX, 0, baud)
  Disable_ABC_fast
  K30.Stop

  K30.StartRxTx(CO2_TX_4, CO2_RX, 0, baud)
  Disable_ABC_fast
  K30.Stop

  K30.StartRxTx(CO2_TX_5, CO2_RX, 0, baud)
  Disable_ABC_fast
  K30.Stop

  K30.StartRxTx(CO2_TX_6, CO2_RX, 0, baud)
  Disable_ABC_fast
  K30.Stop

  K30.StartRxTx(CO2_TX_7, CO2_RX, 0, baud)
  Disable_ABC_fast
  K30.Stop

PUB Disable_ABC_fast  'without serial terminal reply

    repeat while K30.RxCount > 0
      K30.CharIn

    K30.char($FE)
    K30.char($06)
    K30.char($00)
    K30.char($1F)
    K30.char($00)
    K30.char($00)
    K30.char($AC)
    K30.char($03)
  
  waitcnt(cnt + clkfreq) 
         
PUB Read_Sensors  

  sht.start(SHT_DATA,SHT_CLK)
  f.start
  sht.config(33,sht#off,sht#yes,sht#hires)
  tempC := celsius(f.FFloat(sht.readHumidity))
  tempC1 := F.FMul(celsius(f.FFloat(sht.readTemperature)),10.0)     {floating point raw measurement temp}
  tempC3 :=f.FTrunc(tempC1)                              { integer to calculate/use  }

  lv1 := humidity(tempC, f.FFloat(sht.readHumidity))   {floating poitn ram measurement RH }
  lv3 :=f.FTrunc(lv1)


  K30.StartRxTx(CO2_TX_1, CO2_RX, 0, 9600)
    repeat while K30.RxCount > 0
      K30.CharIn

    K30.char($FE)
    K30.char($04)
    K30.char($00)
    K30.char($03)
    K30.char($00)
    K30.char($01)
    K30.char($D5)
    K30.char($C5)
  
    ' Recieve packet
    if K30.charIn == 254
      if K30.charIn == 4
        if K30.charIn == 2
          value := K30.charIn * 256
          value += K30.charIn

          Co2_1 := value   
  K30.Stop    
  
    waitcnt(clkfreq+cnt)
    
  K30.StartRxTx(CO2_TX_2, CO2_RX, 0, 9600)
    repeat while K30.RxCount > 0
      K30.CharIn

    K30.char($FE)
    K30.char($04)
    K30.char($00)
    K30.char($03)
    K30.char($00)
    K30.char($01)
    K30.char($D5)
    K30.char($C5)
  
    ' Recieve packet
    if K30.charIn == 254
      if K30.charIn == 4
        if K30.charIn == 2
          value := K30.charIn * 256
          value += K30.charIn

          Co2_2 := value   
  K30.Stop      
  
    waitcnt(clkfreq+cnt)
    
  K30.StartRxTx(CO2_TX_3, CO2_RX, 0, 9600)
    repeat while K30.RxCount > 0
      K30.CharIn

    K30.char($FE)
    K30.char($04)
    K30.char($00)
    K30.char($03)
    K30.char($00)
    K30.char($01)
    K30.char($D5)
    K30.char($C5)
  
    ' Recieve packet
    if K30.charIn == 254
      if K30.charIn == 4
        if K30.charIn == 2
          value := K30.charIn * 256
          value += K30.charIn

          Co2_3 := value   
  K30.Stop      
  
    waitcnt(clkfreq+cnt)
    
  K30.StartRxTx(CO2_TX_4, CO2_RX, 0, 9600)
    repeat while K30.RxCount > 0
      K30.CharIn

    K30.char($FE)
    K30.char($04)
    K30.char($00)
    K30.char($03)
    K30.char($00)
    K30.char($01)
    K30.char($D5)
    K30.char($C5)
  
    ' Recieve packet
    if K30.charIn == 254
      if K30.charIn == 4
        if K30.charIn == 2
          value := K30.charIn * 256
          value += K30.charIn

          Co2_4 := value   
  K30.Stop      
  
    waitcnt(clkfreq+cnt)
    
  K30.StartRxTx(CO2_TX_5, CO2_RX, 0, 9600)
    repeat while K30.RxCount > 0
      K30.CharIn

    K30.char($FE)
    K30.char($04)
    K30.char($00)
    K30.char($03)
    K30.char($00)
    K30.char($01)
    K30.char($D5)
    K30.char($C5)
  
    ' Recieve packet
    if K30.charIn == 254
      if K30.charIn == 4
        if K30.charIn == 2
          value := K30.charIn * 256
          value += K30.charIn

          Co2_5 := value   
  K30.Stop            
  
    waitcnt(clkfreq+cnt)
    
  K30.StartRxTx(CO2_TX_6, CO2_RX, 0, 9600)
    repeat while K30.RxCount > 0
      K30.CharIn

    K30.char($FE)
    K30.char($04)
    K30.char($00)
    K30.char($03)
    K30.char($00)
    K30.char($01)
    K30.char($D5)
    K30.char($C5)
  
    ' Recieve packet
    if K30.charIn == 254
      if K30.charIn == 4
        if K30.charIn == 2
          value := K30.charIn * 256
          value += K30.charIn

          Co2_6 := value   
  K30.Stop    
  
    waitcnt(clkfreq+cnt)
    
  K30.StartRxTx(CO2_TX_7, CO2_RX, 0, 9600)
    repeat while K30.RxCount > 0
      K30.CharIn

    K30.char($FE)
    K30.char($04)
    K30.char($00)
    K30.char($03)
    K30.char($00)
    K30.char($01)
    K30.char($D5)
    K30.char($C5)
  
    ' Recieve packet
    if K30.charIn == 254
      if K30.charIn == 4
        if K30.charIn == 2
          value := K30.charIn * 256
          value += K30.charIn

          Co2_7 := value   
  K30.Stop        
  
PUB celsius(t)
  ' from SHT1x/SHT7x datasheet using value for 3.5V supply
  ' celsius = -39.7 + (0.01 * t)
  return f.FAdd(-39.7, f.FMul(0.01, t))  
  
PUB humidity(t, rhh) | rhLinear
  ' rhLinear = -2.0468 + (0.0367 * rh) + (-1.5955E-6 * rh * rh)
  ' simplifies to: rhLinear = ((-1.5955E-6 * rh) + 0.0367) * rh -2.0468
  rhLinear := f.FAdd(f.FMul(f.FAdd(0.0367, f.FMul(-1.5955E-6, rhh)), rhh), -2.0468)
  ' rhTrue = (t - 25.0) * (0.01 + 0.00008 * rawRH) + rhLinear
  return f.FAdd(f.FMul(f.FSub(t, 25.0), f.FAdd(0.01, f.FMul(0.00008, rhh))), rhLinear)  
