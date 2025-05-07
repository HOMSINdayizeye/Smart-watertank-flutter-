import 'package:flutter/material.dart';
import 'package:watertank_management/screens/login_screen.dart';
import '../utils/image_placeholders.dart';

class WelcomeScreen extends StatelessWidget {
  
  const WelcomeScreen({Key? key}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("welcome to our App")),
      drawer: Drawer(
        child: ListView(
             padding: EdgeInsets.all(10),
             children: [
              DrawerHeader( 
                decoration: BoxDecoration(color: Colors.blue),
                
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  
                  children:  [
                  ClipOval(
                     child:
                    Image.asset(
                      'assets/amos.png',
                      width: 100,
                      height: 100,
                      fit:BoxFit.cover,
                    )
                  ),
                 const SizedBox(height: 10),
                 const Text('homsindayizeye@water.com'),
                
                  ],
                ),
              
              ),
               ListTile(
                leading: const Icon(Icons.person, color: Colors.amber,),
                title:const Text("my Profile"),
                onTap: () => {},
                  
                 ),
                    ListTile(
                leading: const Icon(Icons.info, color: Colors.pink,),
                title:const Text("my information"),
                ////////////////////hhh
                onTap:() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Information"),
          content: Image.asset(
            'assets/Client-profile.jpg', // Displays the image in the pop-up
            width: 400,
            height: 400,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close"),
            ),
          ],
        );
      },
    );
  },
                  
                 ),
                    ListTile(
                leading: const Icon(Icons.login, color: Colors.amberAccent),
                title:const Text("my Login here"),
                onTap: () => {
                  Navigator.push(context, MaterialPageRoute(builder:(context)=>LoginScreen()))
                },
                  
                 ),
                    ListTile(
                leading: const Icon(Icons.description, color: Colors.purple,),
                title:const Text("my App Description"),
                onTap: () => {},
                  
                 ),
                    ListTile(
                leading: const Icon(Icons.start, color: Colors.cyanAccent,),
                title:const Text("my start Using application"),
                onTap: () => {
                Navigator.push(context, MaterialPageRoute(builder:(context)=>LoginScreen()))},
                  
                 ),

             ]

      
      
              )),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.blue, width: 2),
        ),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: const BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                ),
              ),
              child: const Text(
                'welcome to smart water tank monitoring',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    // Left side with Tank diagram
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 200,
                            child: ImagePlaceholders.tankDiagram(),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Pure Water, Pure Life, Clean\nDrops for a Better Tomorrow',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right side with water drop
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 200,
                            child: ImagePlaceholders.waterDrop(
                                height: 200, width: 200),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                    ),
                    child: const Text('login'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
}
