import 'package:flutter/material.dart';
import '../widgets/chat_message.dart';

const String kFallbackHead = 'assets/image/headimg_dl.jpg';
const String kFallbackAvatarAsset = 'assets/image/img_avatar.png';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const Text(
                      '🍬 关于ZY沂沨',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: '想与 ',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          TextSpan(
                            text: 'ZY沂沨大人',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: ' 一起愉快的 ',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          TextSpan(
                            text: '深入♂交流',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: ' 嘛',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ZY沂沨是个好名字，既简单又可爱，当然也很好记就是有些绕口。所以来访的朋友称呼我『大帅比』就可以啦~本ZY沂沨是不会在意的啦~',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.6,
                            ),
                          ),
                          SizedBox(height: 15),
                          Text(
                            'ZY沂沨来自于美丽的西南方城市，所以说ZY沂沨都是爱吃米的啦~当然除了米，ZY沂沨也是啥都爱吃！但是，除了吃，ZY沂沨也喜欢读读书看看动漫，喝喝奶茶泡泡脚ω',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    ChatMessage(
                      isSender: true,
                      avatarUrl: kFallbackHead,
                      message: '魔镜魔镜，世界上最帅的人是谁？',
                      messageColor: const Color(0xFFE56600),
                    ),
                    const SizedBox(height: 15),
                    ChatMessage(
                      isSender: false,
                      avatarUrl: kFallbackAvatarAsset,
                      message: '那当然是 ZY沂沨大人 啦~',
                      messageColor: const Color(0xFF4C33E5),
                      highlightText: 'ZY沂沨大人',
                      highlightColor: const Color(0xFFE53333),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
