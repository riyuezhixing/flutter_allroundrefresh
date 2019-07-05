import 'package:flutter/material.dart'
    hide RefreshIndicator, RefreshIndicatorState;
import 'package:flutter_allroundrefresh/src/proview/proqress_view.dart';
import 'package:flutter_allroundrefresh/src/util/dialog_comm.dart';
import 'package:flutter_allroundrefresh/src/smart_refresher.dart';
import 'package:flutter_allroundrefresh/src/bean/comm_bean.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../future_refresh.dart';
import 'dart:async';


class AFutureWidget<T> extends StatefulWidget {

  final bool enablePullDown; //是否开启下拉刷新

  final Widget errorWidget; //404布局头
  final Widget progressWidget; //初始转圈
  final ScrollView childWidget; //具体的展示Widget:ListView...GridView

  Future<dynamic> fRefresh; //刷新方法
  Future<dynamic> fLoading; //加载更多方法，如果不写则表示无上拉加载更多

  final Function dataCallback; //数据回调，用于处理数据
  final Function onRefreshCallback; //刷新回调，用于清理数据，重置page
  final Function onLoadingCallback; //加载更多回调，用于page+1
  final Function tokenInvalidCallback; //Token失效回调，用于处理对应事件

  final normalCode; //获取数据成功的code,默认200
  final tokenInvalidCode; //token失效的code,默认900

  final RefreshIndicator header;
  final LoadIndicator footer;


  AFutureWidget({
    Key key,
    this.enablePullDown = true,
    this.childWidget,
    this.errorWidget,
    this.progressWidget,
    this.fRefresh,
    this.fLoading,
    this.dataCallback,
    this.onRefreshCallback,
    this.onLoadingCallback,
    this.tokenInvalidCallback,
    this.normalCode = '200',
    this.tokenInvalidCode = '900',

    this.header,
    this.footer,
  })
      : super(key: key);


  @override
  State<StatefulWidget> createState() => AFutureWidgetState();


  static AFutureWidgetState of(BuildContext context) {
    return context?.ancestorStateOfType(
        const TypeMatcher<AFutureWidgetState>());
  }
}

class AFutureWidgetState extends State<AFutureWidget> {

  bool refresh = false,
      first = true,
      error = false;
  RefreshController _refreshController;
  var errorMsg = '暂无数据';

  @override
  void initState() {
    _refreshController = new RefreshController(); //刷新框架
    first = true;
    _onRefresh();
    super.initState();
  }

  void _onOffsetCallback(bool isUp, double offset) {
    if (isUp) {} else {}
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: content1(),
    );
  }

  Future<String> checkConnectivity() async {
    var connectivityResult = await(Connectivity().checkConnectivity());
    return connectivityResult == ConnectivityResult.none
        ? '检测到手机没有网络，请打开网络后重试！'
        : (connectivityResult == ConnectivityResult.wifi
        ? '网络差或服务器超时，请稍后重试或使用4G尝试！'
        : '网络差或服务器超时，请稍后重试!');
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }


  void _onRefresh() {
    if (widget.fRefresh != null) {
      _refreshController.loadComplete();
      Future.delayed(const Duration(milliseconds: 1000)).then((val) {
        widget.fRefresh.then((result) {
          if (result != null) {
            first = false;
            error = false;
            CommBean bean = CommBean.fromJson(result);
            if (bean.data == null || bean.data == '') {
              _refreshController.refreshFailed();
            } else {
              _refreshController.refreshFailed();
              widget.onRefreshCallback();
              if (bean.code == widget.normalCode) {
                widget.dataCallback(bean.data);
              } else if (bean.code == widget.tokenInvalidCode) {
                callDialog(
                    title: bean.msg,
                    context: context,
                    cancel: false,
                    callback: () {
                      Navigator.of(context).pop();
                      widget.tokenInvalidCallback();
                    }
                );
              } else {
                errorMsg = bean.msg;
                error = true;
              }
            }
          } else {
            first = false;
            error = true;
            widget.onRefreshCallback();
            _refreshController.refreshFailed();
            checkConnectivity().then((onValue) {
              errorMsg = onValue;
              setState(() {});
            });
          }
          setState(() {});
        });
      });
    }
  }


  void _onLoading() {
    if (widget.fLoading != null) {
      widget.onLoadingCallback();
      Future.delayed(const Duration(milliseconds: 1000)).then((val) {
        widget.fLoading.then((result) {
          if (result != null) {
            CommBean bean = CommBean.fromJson(result);
            if (bean.data == null || bean.data == '') {
              _refreshController.loadFailed();
            } else {
              if (bean.code == '200') {
                _refreshController.loadComplete();
                widget.dataCallback(bean.data);
              } else if (bean.code == '404') {
                _refreshController.loadNoData();
              }
            }
          } else {
            _refreshController.loadFailed();
          }
        });
      });
    }
  }


  Widget content1() {
    return Stack(
      children: <Widget>[
        SmartRefresher(
          enablePullDown: widget.enablePullDown,
          enablePullUp: widget.fLoading == null ? false : true,
          onOffsetChange: _onOffsetCallback,
          header: defaultTargetPlatform == TargetPlatform.iOS
              ? WaterDropHeader()
              : MaterialClassicHeader(),
          footer: ClassicFooter(
              loadingText: '加载中...',
              noDataText: '没有更多数据了',
              idleText: '加载更多',
              failedText: '加载失败，点击重试'),
          controller: _refreshController,
          onRefresh: _onRefresh,
          onLoading: _onLoading,
          child: widget.childWidget,
        ),
        //初始转圈扩展
        new Offstage(
          offstage: first ? false : true,
          child: new Container(
            alignment: Alignment.center,
            color: Colors.white70,
            child: widget.progressWidget == null ? ProgressView() : widget
                .progressWidget,
          ),
        ),
        //错误页面
        new Offstage(
          offstage: error ? false : true,
          child: new Container(
            color: Colors.white70,
            child: GestureDetector(
              onTap: () {
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  _refreshController.requestRefresh();
                });
              },
              child: widget.errorWidget == null ? Text(errorMsg) :
              Column(children: <Widget>[
                widget.errorWidget,
                Text(errorMsg),
              ],)
              ,
            ),
          ),
        )
      ],
    );
  }
}
