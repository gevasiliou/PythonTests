import com.beanit.openiec61850.*;
import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.List;

public class IedClient {
    public static void main(String[] args) {
        try {
            // Create the client connection
            InetAddress iedAddress = InetAddress.getByName("192.168.0.100"); // Replace with your IED's IP
            ClientSap clientSap = new ClientSap();
            ClientAssociation association = clientSap.associate(iedAddress, 102, "clientId", null); // Use a valid clientId

            // Access the data object from the IED
            // Note: You may need to adjust the node path based on your IED configuration
            FcModelNode valueNode = association.getModelNode("IED1/MMXU1.TotW.mag.f", Fc.MX); // Use the correct path
//          FcModelNode valueNode = association.getModelNodesFromTypeSpecification("IED1/MMXU1.TotW.mag.f", Fc.MX);
            // Print the value
            if (valueNode != null) {
                Float value = valueNode.getValue().floatValue(); // Ensure you have the correct method to get the value
                System.out.println("Total active power: " + value);
            } else {
                System.out.println("Value node not found.");
            }

            // Close the connection
            association.close();
        } catch (UnknownHostException e) {
            System.err.println("Invalid IP address.");
            e.printStackTrace();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
