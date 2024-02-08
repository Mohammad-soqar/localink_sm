import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/providers/user_provider.dart';
import 'package:localink_sm/resources/firestore_methods.dart';
import 'package:localink_sm/screens/comment_screen.dart';
import 'package:localink_sm/screens/login_screen.dart';
import 'package:localink_sm/screens/profile_screen.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:intl/intl.dart';
import 'package:localink_sm/utils/utils.dart';
import 'package:localink_sm/widgets/like_animation.dart';
import 'package:provider/provider.dart';

class PostCard extends StatefulWidget {
  final snap;
  const PostCard({super.key, required this.snap});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int commentLen = 0;
  bool isLikeAnimating = false;

  @override
  void initState() {
    super.initState();
    fetchCommentLen();
  }



  fetchCommentLen() async {
    try {
      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.snap['postId'])
          .collection('comments')
          .get();
      commentLen = snap.docs.length;
    } catch (err) {}
  }

  @override
  Widget build(BuildContext context) {
    final model.User? user = Provider.of<UserProvider>(context).getUser;
    return Container(
      color: darkBackgroundColor,
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        margin: EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: darkLBackgroundColor, // Your background color
          boxShadow: [
            BoxShadow(
              color: highlightColor.withOpacity(0.1), // Shadow color
              spreadRadius: 2, // Spread radius
              blurRadius: 25, // Blur radius
              offset: Offset(0, 3), // changes position of shadow
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 1,
              ).copyWith(right: 0),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(
                            uid: widget.snap[
                                "uid"],
                          ),
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              NetworkImage(widget.snap['profileImage']),
                          radius: 16,
                        ),
                        title: Text(widget.snap['username'],style: TextStyle(fontSize: 14),),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (context) => Dialog(
                                child: ListView(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shrinkWrap: true,
                                    children: ['delete']
                                        .map(
                                          (e) => InkWell(
                                            onTap: () async {
                                              FireStoreMethods().deletePost(
                                                  widget.snap['postId']);
                                              Navigator.of(context).pop();
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 12,
                                                horizontal: 16,
                                              ),
                                              child: Text(e),
                                            ),
                                          ),
                                        )
                                        .toList()),
                              ));
                    },
                    icon: Icon(Icons.more_vert),
                  ),
                ],
              ),
            ),
            //IMAGE SEACTION
            GestureDetector(
              onDoubleTap: () async {
                await FireStoreMethods().likePost(
                  user!.uid,
                  widget.snap['postId'],
                  widget.snap['hashtags'].cast<String>(),
                );
                setState(() {
                  isLikeAnimating = true;
                });
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.45,
                    width: double.infinity,
                    child: Image.network(
                      widget.snap['postUrl'],
                      fit: BoxFit.cover,
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isLikeAnimating ? 1 : 0,
                    child: Container(
                      color: Colors.black.withOpacity(
                          0.5), // Semi-transparent black background
                      height: MediaQuery.of(context).size.height * 0.45,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: LikeAnimation(
                        child: const Icon(Icons.favorite,
                            color: Colors.white, size: 100),
                        isAnimating: isLikeAnimating,
                        duration: const Duration(milliseconds: 400),
                        onEnd: () {
                          setState(() {
                            isLikeAnimating = false;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            //like comment

            Row(
              children: <Widget>[
                LikeAnimation(
                  isAnimating: widget.snap['likes']?.contains(user?.uid) ?? false,

                  smallLike: true,
                  child: IconButton(
                      icon: widget.snap['likes'].contains(user?.uid)
                          ? const Icon(
                              Icons.favorite,
                              color: highlightColor,
                            )
                          : const Icon(
                              Icons.favorite_border,
                            ),
                      onPressed: () async {
                        await FireStoreMethods().likePost(
                          user!.uid,
                          widget.snap['postId'],
                          widget.snap['hashtags'].cast<String>(),
                        );
                      }),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.comment_outlined,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CommentsScreen(
                        snap: widget.snap['postId'].toString(),
                      ),
                    ),
                  ),
                ),
                IconButton(
                    icon: const Icon(
                      Icons.send,
                    ),
                    onPressed: () {
                      
                    }),
                Expanded(
                    child: Align(
                  alignment: Alignment.bottomRight,
                  child: IconButton(
                      icon: const Icon(Icons.bookmark_border),
                      onPressed: () {}),
                ))
              ],
            ),
            //DESCRIPTION AND NUMBER OF COMMENTS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DefaultTextStyle(
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall!
                          .copyWith(fontWeight: FontWeight.w800),
                      child: Text(
                        '${widget.snap['likes'].length} likes',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )),
                      
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(
                      top: 8,
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: primaryColor),
                        children: [
                          TextSpan(
                            text: widget.snap['username'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          TextSpan(
                            text: ' ${widget.snap['description']}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'View all comments',
                          style: const TextStyle(
                            fontSize: 14,
                            color: greyColor,
                          ),
                        ),
                      ),
                       onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CommentsScreen(
                        snap: widget.snap['postId'].toString(),
                      ),
                    ),
                  ),
                      ),
                     
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      DateFormat.yMMMd()
                          .format(widget.snap['datePublished'].toDate()),
                      style: const TextStyle(
                        color: greyColor,
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
