import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:html';
import 'package:shortid/shortid.dart';

void main() {
  runApp(MyApp());
}

String room = '';

class MyApp extends StatelessWidget {

  // Create the initilization Future outside of `build`:
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();
  final Future<SharedPreferences> prefs = SharedPreferences.getInstance();

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([_initialization,prefs]),
      builder: (context, snapshot) {
        if(snapshot.hasError) {
          return SomethingWentWrong();
        }
        
        if(snapshot.connectionState == ConnectionState.done) {
          print(snapshot.data.hashCode);

          var acquiredPrefs = (snapshot.data[1] as SharedPreferences);
          if(acquiredPrefs.getString('tempchat_id') == null){
            print("No initial sharedpref found!");
            acquiredPrefs.setString('tempchat_id', Uuid().v1());
          }
          print("Welcome, id = " + acquiredPrefs.getString('tempchat_id'));

          return MaterialApp(
            title: 'Flutter Demo',
            theme: ThemeData(
              // This is the theme of your application.
              //
              // Try running your application with "flutter run". You'll see the
              // application has a blue toolbar. Then, without quitting the app, try
              // changing the primarySwatch below to Colors.green and then invoke
              // "hot reload" (press "r" in the console where you ran "flutter run",
              // or simply save your changes to "hot reload" in a Flutter IDE).
              // Notice that the counter didn't reset back to zero; the application
              // is not restarted.
              primarySwatch: Colors.blue,
              fontFamily: 'Roboto',
              // This makes the visual density adapt to the platform that you run
              // the app on. For desktop platforms, the controls will be smaller and
              // closer together (more dense) than on mobile platforms.
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            initialRoute: '/' + shortid.generate(),
            onGenerateRoute: (routeSettings) {
              print('Room: ' +  routeSettings.name);
              room = routeSettings.name;
              return new MaterialPageRoute(
                builder: (context) => MyHomePage(id:acquiredPrefs.getString('tempchat_id')),
                settings: routeSettings
              );
            },
          );
        }

        return Loading();
      }
    );
    
  }
}

class SomethingWentWrong extends StatelessWidget {
  @override
  Widget build(BuildContext context){
    return Text("Uh oh, something went wrong!", textDirection: TextDirection.ltr,);
  }
}

class Loading extends StatelessWidget {
  @override
  Widget build(BuildContext context){
    return Text("Still loading!", textDirection: TextDirection.ltr,);
  }
}

class MessagesView extends StatefulWidget {
  MessagesView({Key key, this.id}) : super(key: key);

  final String id;
  
  @override
  _MessagesViewState createState() => _MessagesViewState();
}

class _MessagesViewState extends State<MessagesView> {

  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context){
    if(room == '') return Container();
    Query messages = FirebaseFirestore.instance.collection(room).orderBy('time', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: messages.snapshots(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return Text('Something went wrong: ' + snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text("Loading");
        }

        return new ListView(
          shrinkWrap: true,
          reverse: true,
          controller: _scrollController,
          children: snapshot.data.docs.map((DocumentSnapshot document) {
            return new Message(data: document.data(), id: widget.id);
          }).toList(),
        );
      },
    );
  }
}

class Message extends StatelessWidget {
  const Message({
    Key key,
    this.data, this.id}) : super(key: key);

  final Map data;
  final String id;

  @override
  Widget build(BuildContext context){
    
    return new Row(
      mainAxisAlignment: data['name'].toString() == id ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        new ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 400.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(10.0)),
              color: data['name'].toString() == id ? Color.fromRGBO(50, 50, 200, 1.0) : Color.fromRGBO(50, 50, 50, 1.0),
            ),
            padding: EdgeInsets.fromLTRB(15, 15, 15, 15),
            margin: EdgeInsets.all(5),
            child: SelectableText(data['content'], textDirection: TextDirection.ltr, style: TextStyle(color: Colors.white))
          )
        )
      ],
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.id}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String id;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Material(
      color: Color.fromRGBO(30, 30, 30, 1.0),
      child: Center(
        child: Container(
          // decoration: BoxDecoration(
          //   border: Border.all(
          //     color: Color.fromRGBO(255, 255, 255, 0.2),
          //     width: 2.0,
          //   ),
          //   borderRadius: BorderRadius.all(Radius.circular(15.0)),
          // ),
          alignment: Alignment.center,
          padding: EdgeInsets.all(5),
          margin: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 20.0),
          constraints: BoxConstraints(maxHeight: 1200.0, maxWidth: 600.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              RoomText(),
              Expanded(child: MessagesView(id: widget.id)),
              ComposeView(id: widget.id)
            ],
          )
        )
      )
    );
  }
}

class ComposeView extends StatefulWidget{
  ComposeView({Key key, this.id}) : super(key: key);

  final String id;
  @override
  _ComposeViewState createState() => _ComposeViewState();
}

class _ComposeViewState extends State<ComposeView>{
  TextEditingController _editingController;

  @override
  void initState() {
    super.initState();
    _editingController = TextEditingController();
  }

  @override
  void dispose() {
    _editingController.dispose();
    super.dispose();
  }

  void submitMessage() {
    print(_editingController.text);
    var message = {
      'name': widget.id,
      'content': _editingController.text,
      'time': DateTime.now()};
    FirebaseFirestore.instance.collection(room).add(message);
    _editingController.text = '';
  }

  @override
  Widget build(BuildContext context){
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(5),
      // constraints: BoxConstraints(minHeight: 40.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: BoxConstraints(minHeight: 50.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(20.0)),
                color: Color.fromRGBO(50, 50, 50, 1.0),
              ),
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.fromLTRB(15, 0, 15, 0),
              child: RawKeyboardListener(
                focusNode: FocusNode(),
                onKey: (event) {
                  if(event.isControlPressed && event.logicalKey == LogicalKeyboardKey.enter && event.runtimeType == RawKeyDownEvent){
                    submitMessage();
                  }
                },
                child: TextField(
                  controller: _editingController,
                  decoration: InputDecoration(
                    disabledBorder: InputBorder.none,
                    border: InputBorder.none,
                  ),
                  cursorColor: Colors.white,
                  style: TextStyle(color: Colors.white),
                  maxLines: null
                )
              )
              
            ),
          ),
          Container(
            height: 50.0,
            width: 50.0,
            margin: EdgeInsets.only(left: 10.0),
            child: Material(
              color: Color.fromRGBO(50, 50, 50, 1.0),
              borderRadius: BorderRadius.all(Radius.circular(40.0)),
              child: MaterialButton(
                onPressed: () => submitMessage(),
                child: Icon(Icons.send, color: Colors.white)
              )
            )
            

            // decoration: BoxDecoration(
            //     borderRadius: BorderRadius.all(Radius.circular(100.0)),
            //     color: Color.fromRGBO(50, 50, 50, 1.0),
            //   ),
            // padding: EdgeInsets.all(10.0),
            // margin: EdgeInsets.only(left: 10.0),
            // child: Icon(Icons.send, color: Colors.white)
          )
          
        ],
      )
    );
  }
}

class RoomText extends StatelessWidget{
  @override
  Widget build(BuildContext context){
    return Column(
      children: [
        SelectableText(window.location.href, textDirection: TextDirection.ltr, style: TextStyle(color: Colors.white, fontSize: 15.0)),
        Text("Share this URL to share this space with your friends!", textDirection: TextDirection.ltr, style: TextStyle(color: Colors.white, fontSize: 15.0)),
      ],
    );
  }
}