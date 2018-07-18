module test.http.router.handler.template;

import java.util.Arrays;
import hunt.container.List;

/**
 * 
 */
public class Example {

    List<Item> items() {
        return Arrays.asList(
                new Item("Item 1", "$19.99", Arrays.asList(new Feature("New!"), new Feature("Awesome!"))),
                new Item("Item 2", "$29.99", Arrays.asList(new Feature("Old."), new Feature("Ugly.")))
        );
    }

    static class Item {
        Item(string name, string price, List<Feature> features) {
            this.name = name;
            this.price = price;
            this.features = features;
        }

        string name, price;
        List<Feature> features;
    }

    static class Feature {
        Feature(string description) {
            this.description = description;
        }

        string description;
    }

}
