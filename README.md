# FreeIPA
Documenteção e arquivos base de configuração para aplicação de politicas de governaça em estações de trabalho e servidores on premise

  # ====================================
  # LÓGICA PARA NOMEAR MAQUINAS
  # ====================================
  **Todo o novo precisa esta em letras minusculas.**
  
  # Setores: 
  IMPLANTAÇÃO = implat 
  PRODUÇÃO = prod 
  SUPORTE = sup 
  COMERCIAL = com 
  ADMINSTRATIVO / RH = admr 
  DESENVOLVIMENTO = dev 
  RESERVA = reserv 

  # Tipos de maquinas: 
 Estações de trabalho = p 
 Servidor = s 
 Kiosk (TVs) = k 
 Notebook = n 
  
  # Setor + '-' +  tipo de maquina + número (01 ...) 
  Ex.: reserv-n01.gs.internal
  Ex.: prod-p03.gs.internal
  
Obs: 
- Sempre verificar no FreeIPA se existe algum número disponivel antes do ultimo naquele setor.  Essa medida visa manter a organização.
- Permita o cliente do FreeIPA executar como deamon
- Quando o Kerberos solicitar o endereço sempre insira em maiusculo GS.INTERNAL
