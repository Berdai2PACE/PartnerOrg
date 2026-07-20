import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import updateOpportunityAmounts from '@salesforce/apex/IncreaseOpportunityAmountController.updateOpportunityAmounts';

export default class IncreaseOpptyAmount extends LightningElement {
    @api recordId;

    percentage;
    isLoading = false;

    get isApplyDisabled() {
        return this.isLoading || this.percentage === undefined || this.percentage === null || this.percentage === '';
    }

    handlePercentageChange(event) {
        this.percentage = event.target.value;
    }

    handleApply() {
        if (this.isApplyDisabled) {
            return;
        }

        this.isLoading = true;

        updateOpportunityAmounts({ accountId: this.recordId, percentage: this.percentage })
            .then((updatedCount) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: `${updatedCount} Opportunity Amount(s) updated by ${this.percentage}%.`,
                        variant: 'success'
                    })
                );
                this.closeAction();
            })
            .catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error updating Opportunities',
                        message: (error && error.body && error.body.message) || error.message,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    closeAction() {
        // No-op if not launched as a screen action; safe to call in either context.
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}