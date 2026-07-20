public with sharing class IncreaseOpportunityAmountController {

    @AuraEnabled
    public static Integer updateOpportunityAmounts(Id accountId, Decimal percentage) {
        if (accountId == null || percentage == null) {
            throw new AuraHandledException('Account and percentage are required.');
        }

        List<Opportunity> oppsToUpdate = [
            SELECT Id, Amount
            FROM Opportunity
            WHERE AccountId = :accountId
            AND StageName != 'Closed Won'
        ];

        for (Opportunity opp : oppsToUpdate) {
            Decimal currentAmount = opp.Amount == null ? 0 : opp.Amount;
            opp.Amount = currentAmount + (currentAmount * percentage / 100);
        }

        if (!oppsToUpdate.isEmpty()) {
            try {
                update oppsToUpdate;
            } catch (DmlException e) {
                throw new AuraHandledException('Error updating Opportunities: ' + e.getMessage());
            }
        }

        return oppsToUpdate.size();
    }
}