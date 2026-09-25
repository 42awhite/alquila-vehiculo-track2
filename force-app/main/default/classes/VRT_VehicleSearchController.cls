public with sharing class VRT_VehicleSearchController
{
    // Único método del buscador: recibe el texto que el usuario escribió y devuelve
    // los vehículos cuya Matrícula, Marca o Modelo lo contengan (texto parcial, en cualquier parte)
    @AuraEnabled
    public static List<VRT_Vehicle__c> searchVehicles(String searchTerm)
    {
        // Protección: Salesforce necesita un mínimo razonable de texto para que la búsqueda
        // tenga sentido; si está vacío o es demasiado corto, devolvemos lista vacía sin consultar nada
        if (String.isBlank(searchTerm) || searchTerm.length() < 2)
        {
            return new List<VRT_Vehicle__c>();
        }

        // Añadimos el símbolo % a los dos lados del texto — esto es lo que hace que LIKE
        // encuentre el texto buscado en CUALQUIER posición dentro del campo, no solo al principio
        String searchPattern = '%' + searchTerm + '%';

        // Consulta única que busca en los 3 campos exactos que pide el enunciado (Matrícula, Marca, Modelo),
        // combinados con OR: basta con que el texto aparezca en UNO cualquiera de los tres.
        // WITH USER_MODE es la forma moderna (reemplaza a SECURITY_ENFORCED) de comprobar
        // automáticamente que el usuario tiene permiso para ver el objeto y los campos consultados.
        List<VRT_Vehicle__c> vehicles = [
            SELECT Id, VRT_TXT_LicensePlate__c, VRT_TXT_Brand__c, VRT_TXT_Model__c, VRT_SEL_VehicleType__c, VRT_SEL_Status__c
            FROM VRT_Vehicle__c
            WHERE VRT_TXT_LicensePlate__c LIKE :searchPattern
               OR VRT_TXT_Brand__c LIKE :searchPattern
               OR VRT_TXT_Model__c LIKE :searchPattern
            WITH USER_MODE
        ];

        return vehicles;
    }
}