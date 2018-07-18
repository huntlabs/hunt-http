module test.mixed;

public class Food {
    protected string name;
    protected double price;

    public string getName() {
        return name;
    }

    public void setName(string name) {
        this.name = name;
    }

    public double getPrice() {
        return price;
    }

    public void setPrice(double price) {
        this.price = price;
    }

    override
    public string toString() {
        return "Food{" ~
                "name='" ~ name + '\'' +
                ", price=" ~ price +
                '}';
    }
}
