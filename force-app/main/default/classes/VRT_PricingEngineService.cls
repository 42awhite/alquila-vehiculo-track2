public with sharing class VRT_PricingEngineService
{
	// Punto de entrada del Service: recibe el lote completo de Alquileres y calcula su Coste Total
	public static void calculateTotalCost(List<VRT_Rental__c> rentals)
	{
		// Recolectamos en un único recorrido los Ids que necesitaremos consultar después
		Set<Id> vehicleIds = new Set<Id>();
		Set<Id> accountIds = new Set<Id>();
		for (VRT_Rental__c rental : rentals)
		{
			if (rental.VRT_LKP_Vehicle__c != null) 
				vehicleIds.add(rental.VRT_LKP_Vehicle__c);
			if (rental.VRT_LKP_Account__c != null) 
				accountIds.add(rental.VRT_LKP_Account__c);
		}

		// Una sola consulta por cada dato relacionado que necesitamos (cero SOQL dentro de bucles)
		Map<Id, VRT_Vehicle__c> vehiclesById = new Map<Id, VRT_Vehicle__c>(
			[SELECT Id, VRT_SEL_VehicleType__c FROM VRT_Vehicle__c WHERE Id IN :vehicleIds]
		);
		Map<String, VRT_PricingRule__mdt> pricingByKey = buildPricingMap();
		Map<Id, Integer> loyaltyCounts = getLoyaltyCounts(accountIds);

		// Calculamos el coste de cada Alquiler usando solo los mapas ya construidos en memoria
		for (VRT_Rental__c rental : rentals)
			calculateSingleRentalCost(rental, vehiclesById, pricingByKey, loyaltyCounts);
	}

	// Calcula y asigna el Coste Total de un único Alquiler: tarifa base + fidelidad + penalización
	private static void calculateSingleRentalCost(
		VRT_Rental__c rental,
		Map<Id, VRT_Vehicle__c> vehiclesById,
		Map<String, VRT_PricingRule__mdt> pricingByKey,
		Map<Id, Integer> loyaltyCounts)
	{
		String vehicleType = vehiclesById.get(rental.VRT_LKP_Vehicle__c)?.VRT_SEL_VehicleType__c;
		String season = calculateSeason(rental.VRT_DAT_InitialDate__c);
		String key = vehicleType + '_' + season;

		// Sin tarifa válida para esta combinación, bloqueamos solo ese registro
		if (!pricingByKey.containsKey(key))
		{
			rental.addError('No existe tarifa aplicable para: ' + key);
			return;
		}

		Decimal pricePerDay = pricingByKey.get(key).VRT_NUM_PricePerDay__c;
		Decimal totalCost = pricePerDay * rental.VRT_FOR_Duration__c;

		// Fidelidad: 5% de descuento si el cliente tiene 3+ alquileres completados en 12 meses
		Integer loyaltyCount;
		if (loyaltyCounts.containsKey(rental.VRT_LKP_Account__c))
			loyaltyCount = loyaltyCounts.get(rental.VRT_LKP_Account__c);
		else
			loyaltyCount = 0;
		if (loyaltyCount >= 3)
			totalCost = totalCost * 0.95;

		// Penalización: 25% del precio/día por cada día de retraso, si se completó fuera de plazo
		if (rental.VRT_SEL_Status__c == 'Completado' && rental.VRT_DAT_FinalDate__c < System.today())
		{
			Integer daysLate = rental.VRT_DAT_FinalDate__c.daysBetween(System.today());
			totalCost = totalCost + (pricePerDay * 0.25 * daysLate);
		}
		rental.VRT_DIV_TotalCost__c = totalCost;
	}

	// Trae las tarifas administrables (Custom Metadata) indexadas por Tipo+Temporada, sin gastar SOQL
	public static Map<String, VRT_PricingRule__mdt> buildPricingMap()
	{
		Map<String, VRT_PricingRule__mdt> allRules = VRT_PricingRule__mdt.getAll();
		Map<String, VRT_PricingRule__mdt> pricingByKey = new Map<String, VRT_PricingRule__mdt>();
		for (VRT_PricingRule__mdt rule : allRules.values())
		{
			String key = rule.VRT_SEL_VehicleType__c + '_' + rule.VRT_SEL_Season__c;
			pricingByKey.put(key, rule);
		}
		return pricingByKey;
	}

	// Traduce una fecha en su temporada de negocio (Alta/Media/Baja) según el mes
	public static String calculateSeason(Date rentalDate)
	{
		Integer mes = rentalDate.month();
		if (mes == 1 || mes == 4 || mes == 7 || mes == 8 || mes == 12) 
			return 'Alta';
		else if (mes == 2 || mes == 5 || mes == 6 || mes == 9) 
			return 'Media';
		else if (mes == 3 || mes == 10 || mes == 11) 
			return 'Baja';
		else 
			return 'Desconocida';
	}

	// Cuenta, por cliente, cuántos alquileres ha completado en los últimos 12 meses (para fidelidad)
	public static Map<Id, Integer> getLoyaltyCounts(Set<Id> accountIds)
	{
		Map<Id, Integer> countByAccount = new Map<Id, Integer>();
		List<AggregateResult> results = [
			SELECT VRT_LKP_Account__c acc, COUNT(Id) total
			FROM VRT_Rental__c
			WHERE VRT_LKP_Account__c IN :accountIds
			AND VRT_SEL_Status__c = 'Completado'
			AND VRT_DAT_FinalDate__c = LAST_N_DAYS:365
			GROUP BY VRT_LKP_Account__c
		];
		for (AggregateResult ar : results)
			countByAccount.put((Id) ar.get('acc'), (Integer) ar.get('total'));
		return countByAccount;
	}
}