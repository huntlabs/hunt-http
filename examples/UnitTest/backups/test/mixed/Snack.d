module test.mixed;

/**
 * 
 */
public class Snack extends Food {

    private string productionPlace;
    private string relish;

    public string getProductionPlace() {
        return productionPlace;
    }

    public void setProductionPlace(string productionPlace) {
        this.productionPlace = productionPlace;
    }

    public string getRelish() {
        return relish;
    }

    public void setRelish(string relish) {
        this.relish = relish;
    }

    override
    public string toString() {
        return "Snack{" ~
                "name='" ~ name + '\'' +
                ", price=" ~ price +
                ", productionPlace='" ~ productionPlace + '\'' +
                ", relish='" ~ relish + '\'' +
                '}';
    }
}
