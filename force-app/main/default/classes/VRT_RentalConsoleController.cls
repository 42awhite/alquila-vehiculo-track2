public with sharing class VRT_RentalConsoleController 
{
    // Simula el precio de un alquiler para un vehículo, cuenta y fechas dadas. Aplica descuentos por fidelidad si corresponde.
    @AuraEnabled
    public static Decimal simulatePrice(
        Id vehicleId,
        Id accountId,
        Date startDate,
        Date endDate
    )
    {
        VRT_Vehicle__c vehiculo = [SELECT VRT_SEL_VehicleType__c FROM VRT_Vehicle__c WHERE Id = :vehicleId];

        String season = VRT_PricingEngineService.calculateSeason(startDate);
        Integer duration = startDate.daysBetween(endDate);
        String key = vehiculo.VRT_SEL_VehicleType__c + '_' + season;

        Map<String, VRT_PricingRule__mdt> pricingByKey = VRT_PricingEngineService.buildPricingMap();
        if (!pricingByKey.containsKey(key))
            throw new AuraHandledException('No existe tarifa aplicable para: ' + key);

        Decimal pricePerDay = pricingByKey.get(key).VRT_NUM_PricePerDay__c;
        Decimal totalCost = pricePerDay * duration;

        Map<Id, Integer> loyaltyCounts = VRT_PricingEngineService.getLoyaltyCounts(new Set<Id>{ accountId });
        Integer loyaltyCount;
        if (loyaltyCounts.containsKey(accountId))
            loyaltyCount = loyaltyCounts.get(accountId);
        else
            loyaltyCount = 0;
        if (loyaltyCount >= 3)
            totalCost = totalCost * 0.95;

        return totalCost;
    }
    
    //trae los alquileres Reservado/En curso de esa cuenta concreta.
    @AuraEnabled(cacheable=true)
    public static List<VRT_Rental__c> getActiveRentals(Id accountId)
    {
        return [
            SELECT Id, VRT_LKP_Vehicle__c, VRT_LKP_Vehicle__r.VRT_TXT_Brand__c, VRT_LKP_Vehicle__r.VRT_TXT_Model__c,
                   VRT_DAT_InitialDate__c, VRT_DAT_FinalDate__c,
                   VRT_SEL_Status__c, VRT_DIV_TotalCost__c
            FROM VRT_Rental__c
            WHERE VRT_LKP_Account__c = :accountId
            AND VRT_SEL_Status__c IN ('Reservado', 'En curso')
            ORDER BY VRT_DAT_InitialDate__c DESC
        ];
    }

    // Crea un nuevo alquiler y lo devuelve. Si hay algún error de trigger (sin tarifa, solapamiento...) se traduce a un mensaje legible para el LWC.
    @AuraEnabled
    public static Id createRental(Id vehicleId, Id accountId, Date startDate, Date endDate)
    {
        VRT_Rental__c rental = new VRT_Rental__c(
            VRT_LKP_Vehicle__c = vehicleId,
            VRT_LKP_Account__c = accountId,
            VRT_DAT_InitialDate__c = startDate,
            VRT_DAT_FinalDate__c = endDate,
            VRT_SEL_Status__c = 'Reservado'
        );

        try
        {
            insert rental;
        }
        catch (DmlException e)
        {
            // Traduce el error real del trigger (sin tarifa, solapamiento...) a un mensaje legible para el LWC
            throw new AuraHandledException(e.getDmlMessage(0));
        }

        return rental.Id;
    }
}