public with sharing class VRT_AvailabilityService
{
	// Solo estos dos estados "ocupan" un vehículo; un alquiler cancelado o ya completado no compite por él
	private static final Set<String> ESTADOS_ACTIVOS = new Set<String>{ 'Reservado', 'En curso' };

	public static void checkOverlaps(List<VRT_Rental__c> rentals)
	{
		// Agrupamos los alquileres que llegan (nuevos o editados) según su vehículo,
		// para poder comparar solo entre los que comparten coche/moto
		Map<Id, List<VRT_Rental__c>> rentalsByVehicle = new Map<Id, List<VRT_Rental__c>>();
		Id vehicleId;
		for (VRT_Rental__c rental : rentals)
		{
			vehicleId = rental.VRT_LKP_Vehicle__c;
			if (!rentalsByVehicle.containsKey(vehicleId))
				rentalsByVehicle.put(vehicleId, new List<VRT_Rental__c>());
			rentalsByVehicle.get(vehicleId).add(rental);
		}

		// Guardamos los Ids de los propios alquileres que se están editando ahora mismo,
		// para no compararlos luego contra sí mismos al consultar la base de datos
		Set<Id> currentRentalIds = new Set<Id>();
		for (VRT_Rental__c rental : rentals)
		{
			if (rental.Id != null)
				currentRentalIds.add(rental.Id);
		}

		Set<Id> vehicleIds = rentalsByVehicle.keySet();

		// Traemos de la tabla de Alquileres los que YA existen en BD, activos, para esos mismos vehículos
		// (excluyendo los que se están editando ahora, para no chocar consigo mismos)
		List<VRT_Rental__c> existentes = [
			SELECT Id, VRT_LKP_Vehicle__c, VRT_DAT_InitialDate__c, VRT_DAT_FinalDate__c
			FROM VRT_Rental__c
			WHERE VRT_LKP_Vehicle__c IN :vehicleIds
			AND VRT_SEL_Status__c IN ('Reservado', 'En curso')
			AND Id NOT IN :currentRentalIds
		];

		// Agrupamos también esos alquileres ya existentes por vehículo, mismo truco que arriba
		Map<Id, List<VRT_Rental__c>> existentesByVehicle = new Map<Id, List<VRT_Rental__c>>();
		for (VRT_Rental__c existente : existentes)
		{
			vehicleId = existente.VRT_LKP_Vehicle__c;
			if (!existentesByVehicle.containsKey(vehicleId))
				existentesByVehicle.put(vehicleId, new List<VRT_Rental__c>());
			existentesByVehicle.get(vehicleId).add(existente);
		}

		// Recorremos vehículo por vehículo, comparando cada alquiler nuevo contra dos grupos:
		// el histórico ya guardado en BD, y los demás alquileres del mismo lote que compartan vehículo
		for (Id vehId : rentalsByVehicle.keySet())
		{
			List<VRT_Rental__c> grupoNuevo = rentalsByVehicle.get(vehId);
			List<VRT_Rental__c> grupoExistente = existentesByVehicle.containsKey(vehId)
				? existentesByVehicle.get(vehId)
				: new List<VRT_Rental__c>();

			for (Integer i = 0; i < grupoNuevo.size(); i++)
			{
				VRT_Rental__c candidato = grupoNuevo[i];

				// Si este alquiler ya está cancelado o completado, no hace falta comprobar nada más
				if (!ESTADOS_ACTIVOS.contains(candidato.VRT_SEL_Status__c)) continue;

				Boolean conflicto = false;

				// Comparación 1: contra los alquileres que ya estaban guardados antes
				for (VRT_Rental__c existente : grupoExistente)
				{
					if (candidato.VRT_DAT_InitialDate__c < existente.VRT_DAT_FinalDate__c
						&& candidato.VRT_DAT_FinalDate__c > existente.VRT_DAT_InitialDate__c)
					{
						conflicto = true;
						break;
					}
				}

				// Comparación 2: contra otros alquileres del MISMO lote que van ANTES en la lista
				// (así el primero de un conflicto "gana" y el segundo es el que se bloquea)
				if (!conflicto)
				{
					for (Integer j = 0; j < i; j++)
					{
						VRT_Rental__c otro = grupoNuevo[j];
						if (!ESTADOS_ACTIVOS.contains(otro.VRT_SEL_Status__c)) continue;

						if (candidato.VRT_DAT_InitialDate__c < otro.VRT_DAT_FinalDate__c
							&& candidato.VRT_DAT_FinalDate__c > otro.VRT_DAT_InitialDate__c)
						{
							conflicto = true;
							break;
						}
					}
				}

				// Si ha encontrado algún conflicto en cualquiera de las dos comparaciones, bloqueamos
				if (conflicto)
				{
					candidato.addError('Ya existe un alquiler activo para este vehículo en fechas que se solapan.');
				}
			}
		}
	}
}