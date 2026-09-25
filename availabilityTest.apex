VRT_Vehicle__c v = [SELECT Id FROM VRT_Vehicle__c LIMIT 1];
Account acc = [SELECT Id FROM Account LIMIT 1];

// Alquiler 1: base
VRT_Rental__c r1 = new VRT_Rental__c(
    VRT_LKP_Vehicle__c = v.Id,
    VRT_LKP_Account__c = acc.Id,
    VRT_DAT_InitialDate__c = Date.today().addMonths(2),
    VRT_DAT_FinalDate__c = Date.today().addMonths(2).addDays(5),
    VRT_SEL_Status__c = 'Reservado'
);
insert r1;
System.debug('Alquiler 1 creado OK');

// Alquiler 2: fechas SOLAPADAS con el 1 -> debe bloquear
try {
    insert new VRT_Rental__c(
        VRT_LKP_Vehicle__c = v.Id,
        VRT_LKP_Account__c = acc.Id,
        VRT_DAT_InitialDate__c = Date.today().addMonths(2).addDays(2),
        VRT_DAT_FinalDate__c = Date.today().addMonths(2).addDays(8),
        VRT_SEL_Status__c = 'Reservado'
    );
    System.debug('ERROR: se guardó solapado, algo falla');
} catch (Exception e) {
    System.debug('Bloqueado correctamente: ' + e.getMessage());
}

// Alquiler 3: empieza justo cuando termina el 1 -> caso límite PERMITIDO
try {
    insert new VRT_Rental__c(
        VRT_LKP_Vehicle__c = v.Id,
        VRT_LKP_Account__c = acc.Id,
        VRT_DAT_InitialDate__c = Date.today().addMonths(2).addDays(5),
        VRT_DAT_FinalDate__c = Date.today().addMonths(2).addDays(9),
        VRT_SEL_Status__c = 'Reservado'
    );
    System.debug('Caso límite permitido correctamente');
} catch (Exception e) {
    System.debug('ERROR: bloqueó un caso que debía permitirse: ' + e.getMessage());
}